import { supabaseAdmin } from './supabaseAdmin.ts';
import { sendPushToTokens } from './push.ts';

type PreferenceRow = {
  enabled: boolean;
  favorite_discount_enabled: boolean;
  recommendations_enabled: boolean;
  quiet_hours_start: string | null;
  quiet_hours_end: string | null;
  timezone: string | null;
};

type DispatchStatus =
  | 'sent'
  | 'skipped_daily_cap'
  | 'skipped_quiet_hours'
  | 'skipped_disabled'
  | 'failed';

type DispatchType = 'favorite_discount' | 'recommendation';

export type DispatchInput = {
  userId: string;
  type: DispatchType;
  dedupeKey: string;
  title: string;
  body: string;
  productId?: string | null;
  payload?: Record<string, unknown>;
};

export type DispatchResult = {
  sent: boolean;
  status: DispatchStatus | 'duplicate';
  notificationId?: string;
};

const DAILY_CAP = 2;

function parseHourMinute(input: string | null): [number, number] | null {
  if (!input) return null;
  const raw = input.trim();
  if (!raw) return null;
  const parts = raw.split(':');
  if (parts.length < 2) return null;
  const hh = Number(parts[0]);
  const mm = Number(parts[1]);
  if (!Number.isFinite(hh) || !Number.isFinite(mm)) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;
  return [hh, mm];
}

function userMinutesNow(timezone: string): number {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: timezone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  });
  const parts = formatter.formatToParts(now);
  const hh = Number(parts.find((p) => p.type === 'hour')?.value ?? '0');
  const mm = Number(parts.find((p) => p.type === 'minute')?.value ?? '0');
  return (hh * 60) + mm;
}

function isInQuietHours(pref: PreferenceRow): boolean {
  const start = parseHourMinute(pref.quiet_hours_start);
  const end = parseHourMinute(pref.quiet_hours_end);
  if (!start || !end) return false;

  const tz = (pref.timezone && pref.timezone.trim().length > 0)
    ? pref.timezone
    : 'Europe/Madrid';

  let nowMinutes = 0;
  try {
    nowMinutes = userMinutesNow(tz);
  } catch (_) {
    nowMinutes = userMinutesNow('Europe/Madrid');
  }

  const startMinutes = (start[0] * 60) + start[1];
  const endMinutes = (end[0] * 60) + end[1];

  if (startMinutes === endMinutes) {
    return false;
  }
  if (startMinutes < endMinutes) {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}

function toPayloadRecord(value: Record<string, unknown> | undefined) {
  if (!value) return {};
  return value;
}

async function getPreferences(userId: string): Promise<PreferenceRow> {
  const { data } = await supabaseAdmin
    .from('notification_preferences')
    .select(
      'enabled,favorite_discount_enabled,recommendations_enabled,quiet_hours_start,quiet_hours_end,timezone',
    )
    .eq('user_id', userId)
    .maybeSingle();

  if (!data) {
    return {
      enabled: true,
      favorite_discount_enabled: true,
      recommendations_enabled: true,
      quiet_hours_start: null,
      quiet_hours_end: null,
      timezone: 'Europe/Madrid',
    };
  }

  return {
    enabled: data.enabled !== false,
    favorite_discount_enabled: data.favorite_discount_enabled !== false,
    recommendations_enabled: data.recommendations_enabled !== false,
    quiet_hours_start: data.quiet_hours_start ?? null,
    quiet_hours_end: data.quiet_hours_end ?? null,
    timezone: data.timezone ?? 'Europe/Madrid',
  };
}

async function getTodaySentCount(userId: string): Promise<number> {
  const now = new Date();
  const startUtc = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    0,
    0,
    0,
    0,
  )).toISOString();

  const response = await supabaseAdmin
    .from('notification_dispatch_log')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('status', 'sent')
    .gte('created_at', startUtc);

  return response.count ?? 0;
}

async function logDispatch(params: {
  notificationId?: string | null;
  userId: string;
  type: string;
  dedupeKey: string;
  status: DispatchStatus;
  details?: Record<string, unknown>;
}) {
  await supabaseAdmin.from('notification_dispatch_log').insert({
    notification_id: params.notificationId ?? null,
    user_id: params.userId,
    type: params.type,
    dedupe_key: params.dedupeKey,
    status: params.status,
    details: params.details ?? {},
  });
}

async function getActiveDeviceTokens(userId: string): Promise<string[]> {
  const { data } = await supabaseAdmin
    .from('notification_devices')
    .select('fcm_token')
    .eq('user_id', userId)
    .eq('is_active', true);

  if (!data || !Array.isArray(data)) return [];
  return data
    .map((row) => String(row.fcm_token ?? '').trim())
    .filter((value) => value.length > 0);
}

export async function createAndDispatchNotification(
  input: DispatchInput,
): Promise<DispatchResult> {
  const existing = await supabaseAdmin
    .from('notification_dispatch_log')
    .select('id')
    .eq('user_id', input.userId)
    .eq('dedupe_key', input.dedupeKey)
    .maybeSingle();

  if (existing.data) {
    return { sent: false, status: 'duplicate' };
  }

  try {
    const preferences = await getPreferences(input.userId);
    if (!preferences.enabled) {
      await logDispatch({
        userId: input.userId,
        type: input.type,
        dedupeKey: input.dedupeKey,
        status: 'skipped_disabled',
        details: { reason: 'notifications_disabled' },
      });
      return { sent: false, status: 'skipped_disabled' };
    }

    if (
      input.type === 'favorite_discount' && !preferences.favorite_discount_enabled
    ) {
      await logDispatch({
        userId: input.userId,
        type: input.type,
        dedupeKey: input.dedupeKey,
        status: 'skipped_disabled',
        details: { reason: 'favorite_discount_disabled' },
      });
      return { sent: false, status: 'skipped_disabled' };
    }

    if (
      input.type === 'recommendation' && !preferences.recommendations_enabled
    ) {
      await logDispatch({
        userId: input.userId,
        type: input.type,
        dedupeKey: input.dedupeKey,
        status: 'skipped_disabled',
        details: { reason: 'recommendations_disabled' },
      });
      return { sent: false, status: 'skipped_disabled' };
    }

    if (isInQuietHours(preferences)) {
      await logDispatch({
        userId: input.userId,
        type: input.type,
        dedupeKey: input.dedupeKey,
        status: 'skipped_quiet_hours',
        details: {
          quiet_hours_start: preferences.quiet_hours_start,
          quiet_hours_end: preferences.quiet_hours_end,
          timezone: preferences.timezone,
        },
      });
      return { sent: false, status: 'skipped_quiet_hours' };
    }

    const sentToday = await getTodaySentCount(input.userId);
    if (sentToday >= DAILY_CAP) {
      await logDispatch({
        userId: input.userId,
        type: input.type,
        dedupeKey: input.dedupeKey,
        status: 'skipped_daily_cap',
        details: { sent_today: sentToday, daily_cap: DAILY_CAP },
      });
      return { sent: false, status: 'skipped_daily_cap' };
    }

    const insertPayload = {
      user_id: input.userId,
      type: input.type,
      title: input.title,
      body: input.body,
      product_id: input.productId ?? null,
      payload: toPayloadRecord(input.payload),
      is_read: false,
      sent_push: false,
    };

    const { data: notification, error: insertError } = await supabaseAdmin
      .from('notifications')
      .insert(insertPayload)
      .select('id')
      .single();

    if (insertError || !notification) {
      await logDispatch({
        userId: input.userId,
        type: input.type,
        dedupeKey: input.dedupeKey,
        status: 'failed',
        details: { reason: insertError?.message ?? 'insert_notification_failed' },
      });
      return { sent: false, status: 'failed' };
    }

    const notificationId = String(notification.id);
    const tokens = await getActiveDeviceTokens(input.userId);
    const push = await sendPushToTokens(tokens, {
      title: input.title,
      body: input.body,
      data: {
        type: input.type,
        notification_id: notificationId,
        product_id: input.productId ?? '',
      },
    });

    await supabaseAdmin
      .from('notifications')
      .update({
        sent_push: push.success > 0,
        push_error: push.errors.length > 0 ? push.errors.join(' | ') : null,
      })
      .eq('id', notificationId);

    await logDispatch({
      notificationId,
      userId: input.userId,
      type: input.type,
      dedupeKey: input.dedupeKey,
      status: 'sent',
      details: {
        push_enabled: push.enabled,
        attempted: push.attempted,
        success: push.success,
        failed: push.failed,
      },
    });

    return { sent: true, status: 'sent', notificationId };
  } catch (error) {
    await logDispatch({
      userId: input.userId,
      type: input.type,
      dedupeKey: input.dedupeKey,
      status: 'failed',
      details: {
        error: error instanceof Error ? error.message : String(error),
      },
    });
    return { sent: false, status: 'failed' };
  }
}
