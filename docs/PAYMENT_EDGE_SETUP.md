# Configuracion Pago Nativo Flutter (Supabase Edge + Stripe)

## 1) Secrets en Supabase
Configura estos secrets en el proyecto:

- STRIPE_SECRET_KEY
- STRIPE_WEBHOOK_SECRET
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- SMTP_HOST (ej: smtp.gmail.com)
- SMTP_PORT (587 o 465)
- SMTP_USER
- SMTP_PASS
- EMAIL_FROM

## 2) Deploy functions
Desde el proyecto Flutter:

```bash
supabase functions deploy create-payment-intent
supabase functions deploy stripe-webhook --no-verify-jwt
```

Ajuste recomendado:
- `create-payment-intent`: require JWT (desde Dashboard o CLI config)
- `stripe-webhook`: sin JWT (lo llama Stripe)

## 3) Configurar webhook Stripe
En Stripe Dashboard -> Developers -> Webhooks:

- Endpoint: `https://<PROJECT_REF>.functions.supabase.co/stripe-webhook`
- Events:
  - `payment_intent.succeeded`
  - `charge.refunded`

Copia el signing secret y guardalo en `STRIPE_WEBHOOK_SECRET`.

## 4) Probar flujo
1. Login en app Flutter
2. Ir a detalle de producto
3. Seleccionar talla y completar datos de envio
4. Pagar con PaymentSheet
5. Verificar:
   - pedido en tabla `orders`
   - item en `order_items`
   - stock decrementado en `product_variants`
   - email de factura enviado
