import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { ensureOrderFromPaymentIntent } from '../_shared/order_from_payment_intent.ts';
import { stripe } from '../_shared/stripe.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

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

    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const body = await req.json();
    const paymentIntentId = String(body?.payment_intent_id || '').trim();
    if (!paymentIntentId) {
      return jsonResponse({ error: 'payment_intent_id is required' }, 400);
    }

    const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
    if (!intent.metadata?.user_id || intent.metadata.user_id !== user.id) {
      return jsonResponse({ error: 'Forbidden payment_intent' }, 403);
    }

    if (intent.status !== 'succeeded') {
      return jsonResponse({
        ok: false,
        status: intent.status,
        order_created: false,
      }, 409);
    }

    const result = await ensureOrderFromPaymentIntent({
      id: intent.id,
      amount_received: intent.amount_received,
      receipt_email: intent.receipt_email,
      metadata: intent.metadata as Record<string, string | undefined>,
    });

    return jsonResponse({
      ok: true,
      status: intent.status,
      order_created: true,
      order_id: result.orderId,
      created_now: result.created,
    });
  } catch (error) {
    console.error('[confirm-payment-intent] error', error);
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ ok: false, error: message }, 500);
  }
});
