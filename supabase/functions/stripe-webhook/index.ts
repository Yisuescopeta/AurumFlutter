import Stripe from 'npm:stripe@14';

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

  const signature = req.headers.get('stripe-signature');
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';

  if (!signature || !webhookSecret) {
    return jsonResponse({ error: 'Webhook config invalid' }, 400);
  }

  try {
    const body = await req.text();
    const cryptoProvider = Stripe.createSubtleCryptoProvider();
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret,
      undefined,
      cryptoProvider,
    );

    if (event.type == 'payment_intent.succeeded') {
      const intent = event.data.object as Stripe.PaymentIntent;
      await ensureOrderFromPaymentIntent({
        id: intent.id,
        amount_received: intent.amount_received,
        receipt_email: intent.receipt_email,
        metadata: intent.metadata as Record<string, string | undefined>,
      });
    }

    if (event.type == 'charge.refunded') {
      const charge = event.data.object as Stripe.Charge;
      await onChargeRefunded(charge);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    console.error('[stripe-webhook] error', error);
    return jsonResponse({ error: 'Webhook processing failed' }, 400);
  }
});

async function onChargeRefunded(charge: Stripe.Charge) {
  const paymentIntentId =
    typeof charge.payment_intent == 'string' ? charge.payment_intent : null;
  if (!paymentIntentId) return;

  await supabaseAdmin
    .from('orders')
    .update({
      status: 'refunded',
      refund_status: 'completed',
      refunded_at: new Date().toISOString(),
    })
    .eq('payment_intent_id', paymentIntentId);
}
