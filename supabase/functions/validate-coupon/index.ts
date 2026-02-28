import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type RequestBody = {
  code: string;
  cart_total: number;
};

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
      return jsonResponse({ valid: false, error: 'Unauthorized' }, 401);
    }

    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      return jsonResponse({ valid: false, error: 'Unauthorized' }, 401);
    }

    const body = await req.json() as RequestBody;
    const code = String(body.code || '').trim().toUpperCase();
    const cartTotal = Math.max(0, Number(body.cart_total || 0));

    if (!code) {
      return jsonResponse({ valid: false, error: 'Codigo requerido' }, 400);
    }

    const { data: coupon, error } = await supabaseAdmin
      .from('coupons')
      .select('*')
      .eq('code', code)
      .single();

    if (error || !coupon) {
      return jsonResponse({ valid: false, error: 'Cupon invalido' }, 200);
    }

    if (!coupon.is_active) {
      return jsonResponse({ valid: false, error: 'Este cupon ya no esta activo' }, 200);
    }

    if (coupon.expiration_date && new Date(coupon.expiration_date) < new Date()) {
      return jsonResponse({ valid: false, error: 'Este cupon ha expirado' }, 200);
    }

    if (coupon.usage_limit) {
      const { count } = await supabaseAdmin
        .from('user_coupons')
        .select('*', { count: 'exact', head: true })
        .eq('coupon_id', coupon.id);
      if (count != null && count >= coupon.usage_limit) {
        return jsonResponse({ valid: false, error: 'Este cupon alcanzo su limite de uso' }, 200);
      }
    }

    if (coupon.is_single_use) {
      const { data: usage } = await supabaseAdmin
        .from('user_coupons')
        .select('id')
        .eq('coupon_id', coupon.id)
        .eq('user_id', user.id)
        .maybeSingle();

      if (usage) {
        return jsonResponse({ valid: false, error: 'Ya has utilizado este cupon' }, 200);
      }
    }

    let discountAmount = 0;
    if (coupon.discount_type === 'percent') {
      discountAmount = Math.round((cartTotal * Number(coupon.discount_value || 0)) / 100);
    } else {
      discountAmount = Math.min(Math.round(Number(coupon.discount_value || 0) * 100), cartTotal);
    }

    return jsonResponse({
      valid: true,
      coupon: {
        id: coupon.id,
        code: coupon.code,
        discount_type: coupon.discount_type,
        discount_value: coupon.discount_value,
        usage_limit: coupon.usage_limit,
        is_single_use: coupon.is_single_use,
      },
      discount_amount: discountAmount,
      final_total: Math.max(0, cartTotal - discountAmount),
    });
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return jsonResponse({ valid: false, error: 'Error validando cupon', details }, 500);
  }
});
