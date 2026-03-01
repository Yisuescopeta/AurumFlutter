import Stripe from 'npm:stripe@16.12.0';

const stripeKey = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
if (!stripeKey) {
  throw new Error('Missing STRIPE_SECRET_KEY');
}

export const stripe = new Stripe(stripeKey, {
  apiVersion: '2024-06-20',
});
