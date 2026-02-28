# Advanced Notifications Setup

This project now includes:

- In-app notifications inbox (`/notifications`)
- Device registration for push tokens
- Discount alerts for favorite products (`false -> true` in `is_on_sale`)
- Daily personalized recommendations

Current discount trigger behavior:

- Notify when a favorite product enters sale (`false -> true`).
- Notify when a favorite product is already on sale and `sale_price` drops further.
- First run initializes baseline state (`notification_product_sale_state`) without sending notifications.

## 1) Database (clone environment)

Run this SQL on the cloned database:

- `docs/sql/notifications_schema.sql`

## 2) Edge Functions to deploy

Deploy these functions:

```bash
supabase functions deploy notifications-register-device
supabase functions deploy notifications-discount-favorites-run
supabase functions deploy notifications-recommendations-run
```

Shared modules used:

- `supabase/functions/_shared/notification_dispatch.ts`
- `supabase/functions/_shared/push.ts`

## 3) Environment variables (Supabase Functions)

Required:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Push:

- `FCM_SERVER_KEY` (Firebase Cloud Messaging legacy server key)

Cron protection (optional, recommended):

- `CRON_SECRET`

## 4) Suggested schedules

Use your scheduler or cron service to call:

- `notifications-discount-favorites-run` every 10-15 minutes.
- `notifications-recommendations-run` once per day.

If `CRON_SECRET` is set, send header:

- `x-cron-secret: <CRON_SECRET>`

## 4.1) Verify discount notifications end-to-end

Checklist:

1. Deploy latest functions:
   - `notifications-discount-favorites-run`
   - `notifications-register-device`
2. Confirm cron calls `notifications-discount-favorites-run` every 10-15 min.
3. Ensure the target user has:
   - a row in `favorites` for that product.
   - `notification_preferences.favorite_discount_enabled = true`.
   - at least one active row in `notification_devices` (for push delivery).
4. Run once to create baseline:
   - response should include `baseline_count` > 0 on first execution.
5. Trigger a real change:
   - set `is_on_sale` from `false` to `true` with `sale_price > 0`, OR
   - lower `sale_price` while `is_on_sale = true`.
6. Run function again and inspect response counters:
   - `changed_to_sale`, `price_drops`, `sent`, `skipped`, `duplicates`.
7. Validate data:
   - `public.notifications` has a new `favorite_discount` row for the user.
   - `public.notification_dispatch_log` records status (`sent`, `skipped_*`, etc).

## 5) Android push prerequisites

To enable push delivery on Android:

1. Add `android/app/google-services.json`
2. Configure Firebase for app package `com.aurum.aurum_app`
3. Ensure Firebase Messaging is enabled in the Firebase project

The app falls back to in-app inbox if Firebase is not fully configured.
