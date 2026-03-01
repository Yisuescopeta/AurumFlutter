import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { sendBroadcastEmail } from '../_shared/email.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type CampaignPayload = {
  title?: string;
  subject?: string;
  message?: string;
  include_coupon?: boolean;
  coupon_mode?: 'generic' | 'unique';
  coupon_type?: 'percent' | 'fixed';
  coupon_value?: number;
  coupon_code?: string | null;
  coupon_expiration?: string | null;
};

function normalizeCode(base: string): string {
  return base
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_-]/g, '')
    .slice(0, 40);
}

function randomSuffix(size = 6): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < size; i++) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}

function buildUniqueCode(userId: string): string {
  const chunk = userId.replace(/-/g, '').slice(0, 6).toUpperCase();
  return normalizeCode(`AURUM-${chunk}-${randomSuffix(5)}`);
}

async function assertAdmin(token: string): Promise<string> {
  const {
    data: { user },
    error: userError,
  } = await supabaseAdmin.auth.getUser(token);

  if (userError || !user) {
    throw new Error('Unauthorized');
  }

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError || profile?.role != 'admin') {
    throw new Error('Forbidden');
  }

  return user.id;
}

async function createCoupon(payload: {
  code: string;
  couponType: 'percent' | 'fixed';
  couponValue: number;
  expiration: string | null;
  singleUse: boolean;
  usageLimit: number | null;
}) {
  const { data, error } = await supabaseAdmin
    .from('coupons')
    .insert({
      code: payload.code,
      discount_type: payload.couponType,
      discount_value: payload.couponValue,
      expiration_date: payload.expiration,
      usage_limit: payload.usageLimit,
      is_single_use: payload.singleUse,
      is_active: true,
      min_purchase_amount: 0,
    })
    .select('id,code')
    .single();

  if (error || !data) {
    throw new Error(`No se pudo crear cupon ${payload.code}`);
  }
  return data;
}

async function getOrCreateGenericCoupon(params: {
  requestedCode: string | null | undefined;
  couponType: 'percent' | 'fixed';
  couponValue: number;
  expiration: string | null;
}) {
  const generated = normalizeCode(`AURUM-${randomSuffix(8)}`);
  const code = normalizeCode(params.requestedCode ?? '') || generated;

  const { data: existing } = await supabaseAdmin
    .from('coupons')
    .select('id,code')
    .eq('code', code)
    .maybeSingle();

  if (existing) {
    return existing;
  }

  return createCoupon({
    code,
    couponType: params.couponType,
    couponValue: params.couponValue,
    expiration: params.expiration,
    singleUse: false,
    usageLimit: null,
  });
}

Deno.serve(async (req: Request) => {
  if (req.method == 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method != 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace('Bearer ', '').trim();
    if (!token) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    await assertAdmin(token);
    const body = await req.json() as CampaignPayload;

    const title = String(body.title ?? '').trim();
    const subject = String(body.subject ?? '').trim();
    const message = String(body.message ?? '').trim();
    if (!title || !subject || !message) {
      return jsonResponse({ error: 'title, subject and message are required' }, 400);
    }

    const includeCoupon = body.include_coupon == true;
    const couponMode: 'generic' | 'unique' = body.coupon_mode == 'unique' ? 'unique' : 'generic';
    const couponType: 'percent' | 'fixed' = body.coupon_type == 'fixed' ? 'fixed' : 'percent';
    const couponValue = Number(body.coupon_value ?? 0);
    const expiration = body.coupon_expiration ? String(body.coupon_expiration) : null;

    if (includeCoupon) {
      if (!Number.isFinite(couponValue) || couponValue <= 0) {
        return jsonResponse({ error: 'coupon_value is required when include_coupon=true' }, 400);
      }
      if (couponType == 'percent' && couponValue > 100) {
        return jsonResponse({ error: 'percent coupon cannot exceed 100' }, 400);
      }
    }

    const { data: recipients, error: recipientsError } = await supabaseAdmin
      .from('profiles')
      .select('id,full_name,email')
      .not('email', 'is', null)
      .neq('email', '')
      .order('created_at', { ascending: false });

    if (recipientsError || !recipients) {
      return jsonResponse({ error: 'No se pudieron cargar destinatarios' }, 500);
    }

    let genericCouponCode: string | null = null;
    if (includeCoupon && couponMode == 'generic') {
      const coupon = await getOrCreateGenericCoupon({
        requestedCode: body.coupon_code,
        couponType,
        couponValue,
        expiration,
      });
      genericCouponCode = coupon.code;
    }

    let sent = 0;
    const errors: Array<{ email: string; error: string }> = [];

    for (const recipient of recipients) {
      const email = String(recipient.email ?? '').trim();
      if (!email) {
        continue;
      }

      try {
        let couponCode: string | undefined;
        if (includeCoupon) {
          if (couponMode == 'unique') {
            const created = await createCoupon({
              code: buildUniqueCode(String(recipient.id)),
              couponType,
              couponValue,
              expiration,
              singleUse: true,
              usageLimit: 1,
            });
            couponCode = created.code;
          } else {
            couponCode = genericCouponCode ?? undefined;
          }
        }

        await sendBroadcastEmail({
          to: email,
          subject,
          title,
          message,
          couponCode,
          couponLabel: includeCoupon ? 'Codigo de descuento' : undefined,
        });
        sent += 1;
      } catch (error) {
        errors.push({
          email,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return jsonResponse({
      ok: true,
      total_recipients: recipients.length,
      sent,
      failed: errors.length,
      errors,
      coupon_code: genericCouponCode,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message == 'Unauthorized') {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }
    if (message == 'Forbidden') {
      return jsonResponse({ error: 'Forbidden' }, 403);
    }
    console.error('[send-broadcast-campaign] error', error);
    return jsonResponse({ error: 'No se pudo enviar la campana', details: message }, 500);
  }
});
