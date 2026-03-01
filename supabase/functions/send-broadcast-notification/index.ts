import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import {
  createAndDispatchNotification,
} from '../_shared/notification_dispatch.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type BroadcastPayload = {
  title?: string;
  body?: string;
  route?: string;
  product_id?: string | null;
  coupon_id?: string | null;
  coupon_code?: string | null;
  include_admins?: boolean;
};

function normalizeRoute(input: unknown): string {
  const value = String(input ?? '').trim();
  if (!value) return '/notifications';
  return value.startsWith('/') ? value : '/notifications';
}

Deno.serve(async (req: Request) => {
  if (req.method == 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method != 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const adminId = 'system_admin_broadcast';
    const body = await req.json() as BroadcastPayload;

    const title = String(body.title ?? '').trim();
    const message = String(body.body ?? '').trim();
    const route = normalizeRoute(body.route);
    const productId = body.product_id ? String(body.product_id).trim() : null;
    const couponId = body.coupon_id ? String(body.coupon_id).trim() : null;
    const couponCode = body.coupon_code ? String(body.coupon_code).trim() : null;
    const includeAdmins = body.include_admins !== false;

    if (!title || !message) {
      return jsonResponse({ error: 'title and body are required' }, 400);
    }

    let recipientsQuery = supabaseAdmin
      .from('profiles')
      .select('id');

    if (!includeAdmins) {
      recipientsQuery = recipientsQuery.neq('role', 'admin');
    }

    const { data: recipients, error: recipientsError } = await recipientsQuery;

    if (recipientsError || !recipients) {
      return jsonResponse({ error: 'No se pudieron cargar destinatarios' }, 500);
    }

    const campaignKey = crypto.randomUUID();
    let sent = 0;
    let skipped = 0;
    let duplicates = 0;
    let failed = 0;

    for (const row of recipients) {
      const userId = String(row.id ?? '').trim();
      if (!userId) continue;

      const result = await createAndDispatchNotification({
        userId,
        type: 'admin_broadcast',
        dedupeKey: `admin_broadcast:${campaignKey}:${userId}`,
        title,
        body: message,
        productId: productId || null,
        payload: {
          route,
          type: 'admin_broadcast',
          admin_id: adminId,
          coupon_id: couponId,
          coupon_code: couponCode,
        },
      });

      if (result.sent) {
        sent += 1;
      } else if (result.status == 'duplicate') {
        duplicates += 1;
      } else if (result.status == 'failed') {
        failed += 1;
      } else {
        skipped += 1;
      }
    }

    return jsonResponse({
      ok: true,
      total_recipients: recipients.length,
      sent,
      skipped,
      duplicates,
      failed,
      include_admins: includeAdmins,
    });
  } catch (error) {
    console.error('[send-broadcast-notification] error', error);
    const details = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: 'No se pudo enviar la notificacion', details }, 500);
  }
});
