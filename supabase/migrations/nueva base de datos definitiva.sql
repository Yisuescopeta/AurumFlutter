-- nueva base de datos definitiva
-- Full schema for Aurum + notification system compatible with current app/functions.

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 1. profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text null,
  email text null,
  phone text null,
  address text null,
  city text null,
  postal_code text null,
  avatar_url text null,
  role text not null default 'customer' check (role in ('admin', 'customer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Utility helpers (after profiles exists)
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

create or replace function public.is_service_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    current_setting('request.jwt.claims', true)::json->>'role',
    ''
  ) = 'service_role';
$$;

-- 2. categories
create table if not exists public.categories (
  id uuid primary key default uuid_generate_v4(),
  name text not null check (char_length(name) >= 3),
  slug text unique not null check (slug ~* '^[a-z0-9-]+$'),
  description text null,
  image_url text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. products
create table if not exists public.products (
  id uuid primary key default uuid_generate_v4(),
  category_id uuid null references public.categories(id) on delete set null,
  name text not null check (char_length(name) >= 3),
  slug text unique not null check (slug ~* '^[a-z0-9-]+$'),
  description text null check (char_length(description) <= 2000),
  price integer not null check (price > 0),
  compare_at_price integer null,
  sku text unique null,
  material text null,
  stock integer not null default 0 check (stock >= 0),
  sizes jsonb null,
  images text[] not null default '{}'::text[],
  colors text[] not null default '{}'::text[],
  is_featured boolean not null default false,
  is_active boolean not null default true,
  is_on_sale boolean not null default false,
  sale_price integer null,
  sale_started_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. product_variants
create table if not exists public.product_variants (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid not null references public.products(id) on delete cascade,
  size text not null,
  sku_variant text null,
  stock integer not null default 0 check (stock >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5. site_settings
create table if not exists public.site_settings (
  id text primary key default 'main',
  updated_by uuid null references public.profiles(id) on delete set null,
  show_flash_sales boolean not null default false,
  flash_sales_title text not null default 'Ofertas Flash',
  flash_sales_subtitle text not null default 'Descuentos por tiempo limitado',
  updated_at timestamptz not null default now()
);

-- 6. favorites
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- 7. Legacy preferences (kept for backward compatibility)
create table if not exists public.user_notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references auth.users(id) on delete cascade,
  favorites_on_sale boolean not null default true,
  marketing_emails boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 8. Legacy notification history (kept for backward compatibility)
create table if not exists public.notification_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  email_sent_to varchar null,
  notification_type varchar not null default 'favorite_on_sale',
  sent_at timestamptz not null default now()
);

-- 9. orders
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id) on delete set null,
  payment_intent_id text null,
  stripe_session_id text unique null,
  customer_email text null,
  total_amount integer null,
  status text not null default 'paid' check (
    status in ('pending', 'paid', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')
  ),
  shipping_cost integer not null default 0,
  shipping_address text not null default 'No especificada',
  shipping_city text not null default 'No especificada',
  shipping_postal_code text not null default '00000',
  shipping_phone text null,
  notes text null,
  tracking_number text null,
  carrier text null,
  estimated_delivery timestamptz null,
  shipped_at timestamptz null,
  delivered_at timestamptz null,
  cancelled_at timestamptz null,
  cancellation_reason text null,
  refund_status text null check (refund_status in ('pending', 'completed', 'failed')),
  refunded_at timestamptz null,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fk_orders_profiles'
  ) then
    alter table public.orders
      add constraint fk_orders_profiles
      foreign key (user_id) references public.profiles(id);
  end if;
end $$;

-- 10. order_items
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid null references public.orders(id) on delete set null,
  product_id uuid null references public.products(id) on delete set null,
  product_name text null,
  size text null,
  quantity integer null,
  price_at_purchase integer null
);

-- 11. order_status_history
create table if not exists public.order_status_history (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  notes text null,
  created_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- 12. admin_report_subscriptions
create table if not exists public.admin_report_subscriptions (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid unique not null references auth.users(id) on delete cascade,
  last_sent_at timestamptz null,
  enabled boolean not null default true,
  report_sales boolean not null default true,
  report_new_customers boolean not null default true,
  report_returns boolean not null default true,
  report_low_stock boolean not null default true,
  report_top_products boolean not null default true,
  send_hour integer not null default 8 check (send_hour between 0 and 23),
  send_minute integer not null default 0 check (send_minute between 0 and 59),
  frequency_days integer not null default 1 check (frequency_days between 1 and 30),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 13. coupons
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  discount_type text not null check (discount_type in ('percent', 'fixed')),
  discount_value numeric not null,
  min_purchase_amount numeric not null default 0,
  expiration_date timestamptz null,
  usage_limit integer null,
  is_single_use boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 14. user_coupons
create table if not exists public.user_coupons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  used_at timestamptz not null default now(),
  unique (user_id, coupon_id)
);

-- 15. notification_preferences (new system)
create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  favorite_discount_enabled boolean not null default true,
  recommendations_enabled boolean not null default true,
  quiet_hours_start time null,
  quiet_hours_end time null,
  timezone text not null default 'Europe/Madrid',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 16. notification_devices (new system)
create table if not exists public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  fcm_token text not null,
  device_label text null,
  app_version text null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

-- 17. notifications (new system)
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('favorite_discount', 'recommendation')),
  title text not null,
  body text not null,
  product_id uuid null references public.products(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  sent_push boolean not null default false,
  push_error text null,
  created_at timestamptz not null default now(),
  read_at timestamptz null
);

-- 18. notification_product_sale_state (new system)
create table if not exists public.notification_product_sale_state (
  product_id uuid primary key references public.products(id) on delete cascade,
  last_is_on_sale boolean not null,
  last_sale_price integer null,
  updated_at timestamptz not null default now()
);

-- 19. notification_dispatch_log (new system)
create table if not exists public.notification_dispatch_log (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid null references public.notifications(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  dedupe_key text not null,
  status text not null check (
    status in ('sent', 'skipped_daily_cap', 'skipped_quiet_hours', 'skipped_disabled', 'failed')
  ),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Indexes
create index if not exists idx_categories_active on public.categories(is_active);
create index if not exists idx_products_active on public.products(is_active);
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_products_sale on public.products(is_on_sale, sale_price);
create index if not exists idx_product_variants_product on public.product_variants(product_id);
create index if not exists idx_favorites_user on public.favorites(user_id);
create index if not exists idx_favorites_product on public.favorites(product_id);
create index if not exists idx_orders_user on public.orders(user_id);
create index if not exists idx_order_items_order on public.order_items(order_id);
create index if not exists idx_order_items_product on public.order_items(product_id);
create index if not exists idx_order_status_history_order on public.order_status_history(order_id);
create index if not exists idx_user_coupons_user on public.user_coupons(user_id);
create index if not exists idx_notification_devices_user_active on public.notification_devices(user_id, is_active);
create index if not exists idx_notifications_user_created on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_user_unread on public.notifications(user_id, is_read);
create index if not exists idx_notification_dispatch_user_day on public.notification_dispatch_log(user_id, created_at desc);
create unique index if not exists uq_notification_dispatch_dedupe on public.notification_dispatch_log(user_id, dedupe_key);

-- Updated_at triggers

drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_categories_set_updated_at on public.categories;
create trigger trg_categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_products_set_updated_at on public.products;
create trigger trg_products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists trg_product_variants_set_updated_at on public.product_variants;
create trigger trg_product_variants_set_updated_at
before update on public.product_variants
for each row execute function public.set_updated_at();

drop trigger if exists trg_site_settings_set_updated_at on public.site_settings;
create trigger trg_site_settings_set_updated_at
before update on public.site_settings
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_notification_preferences_set_updated_at on public.user_notification_preferences;
create trigger trg_user_notification_preferences_set_updated_at
before update on public.user_notification_preferences
for each row execute function public.set_updated_at();

drop trigger if exists trg_admin_report_subscriptions_set_updated_at on public.admin_report_subscriptions;
create trigger trg_admin_report_subscriptions_set_updated_at
before update on public.admin_report_subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists trg_notification_preferences_set_updated_at on public.notification_preferences;
create trigger trg_notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

drop trigger if exists trg_notification_devices_set_updated_at on public.notification_devices;
create trigger trg_notification_devices_set_updated_at
before update on public.notification_devices
for each row execute function public.set_updated_at();

-- RLS enable
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.site_settings enable row level security;
alter table public.favorites enable row level security;
alter table public.user_notification_preferences enable row level security;
alter table public.notification_history enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.admin_report_subscriptions enable row level security;
alter table public.coupons enable row level security;
alter table public.user_coupons enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_devices enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_product_sale_state enable row level security;
alter table public.notification_dispatch_log enable row level security;

-- Clean old policies to avoid duplicates

do $$
declare
  p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'profiles','categories','products','product_variants','site_settings','favorites',
        'user_notification_preferences','notification_history','orders','order_items',
        'order_status_history','admin_report_subscriptions','coupons','user_coupons',
        'notification_preferences','notification_devices','notifications',
        'notification_product_sale_state','notification_dispatch_log'
      )
  loop
    execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

-- Profiles
create policy profiles_select_public on public.profiles
for select to public
using (true);

create policy profiles_update_own on public.profiles
for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create policy profiles_insert_admin_or_service on public.profiles
for insert to authenticated
with check (public.is_admin() or public.is_service_role());

create policy profiles_update_admin_or_service on public.profiles
for update to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- Categories
create policy categories_select_active on public.categories
for select to public
using (is_active = true or public.is_admin() or public.is_service_role());

create policy categories_manage_admin on public.categories
for all to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- Products
create policy products_select_active on public.products
for select to public
using (is_active = true or public.is_admin() or public.is_service_role());

create policy products_manage_admin on public.products
for all to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- Product variants
create policy product_variants_select_public on public.product_variants
for select to public
using (true);

create policy product_variants_manage_admin on public.product_variants
for all to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- Site settings
create policy site_settings_select_public on public.site_settings
for select to public
using (true);

create policy site_settings_manage_admin on public.site_settings
for all to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- Favorites
create policy favorites_select_own_or_admin on public.favorites
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy favorites_insert_own on public.favorites
for insert to authenticated
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy favorites_delete_own_or_admin on public.favorites
for delete to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

-- Legacy notification preferences
create policy user_notification_preferences_rw_own on public.user_notification_preferences
for all to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role())
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

-- Legacy notification history
create policy notification_history_select_own_or_admin on public.notification_history
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notification_history_insert_admin on public.notification_history
for insert to authenticated
with check (public.is_admin() or public.is_service_role());

-- Orders
create policy orders_select_own_or_admin on public.orders
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy orders_insert_own_or_guest on public.orders
for insert to authenticated
with check (auth.uid() = user_id or user_id is null or public.is_admin() or public.is_service_role());

create policy orders_update_admin on public.orders
for update to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

create policy orders_delete_admin on public.orders
for delete to authenticated
using (public.is_admin() or public.is_service_role());

-- Order items
create policy order_items_select_own_or_admin on public.order_items
for select to authenticated
using (
  public.is_admin() or public.is_service_role()
  or exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

create policy order_items_insert_admin on public.order_items
for insert to authenticated
with check (public.is_admin() or public.is_service_role());

create policy order_items_update_admin on public.order_items
for update to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

create policy order_items_delete_admin on public.order_items
for delete to authenticated
using (public.is_admin() or public.is_service_role());

-- Order status history
create policy order_status_history_select_own_or_admin on public.order_status_history
for select to authenticated
using (
  public.is_admin() or public.is_service_role()
  or exists (
    select 1 from public.orders o
    where o.id = order_status_history.order_id
      and o.user_id = auth.uid()
  )
);

create policy order_status_history_insert_admin on public.order_status_history
for insert to authenticated
with check (public.is_admin() or public.is_service_role());

-- Admin report subscriptions
create policy admin_report_subscriptions_select_own_admin on public.admin_report_subscriptions
for select to authenticated
using (auth.uid() = admin_user_id and (public.is_admin() or public.is_service_role()));

create policy admin_report_subscriptions_insert_own_admin on public.admin_report_subscriptions
for insert to authenticated
with check (auth.uid() = admin_user_id and (public.is_admin() or public.is_service_role()));

create policy admin_report_subscriptions_update_own_admin on public.admin_report_subscriptions
for update to authenticated
using (auth.uid() = admin_user_id and (public.is_admin() or public.is_service_role()))
with check (auth.uid() = admin_user_id and (public.is_admin() or public.is_service_role()));

create policy admin_report_subscriptions_delete_own_admin on public.admin_report_subscriptions
for delete to authenticated
using (auth.uid() = admin_user_id and (public.is_admin() or public.is_service_role()));

-- Coupons
create policy coupons_select_public on public.coupons
for select to public
using (is_active = true or public.is_admin() or public.is_service_role());

create policy coupons_manage_admin on public.coupons
for all to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- User coupons
create policy user_coupons_select_own_or_admin on public.user_coupons
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy user_coupons_manage_admin on public.user_coupons
for all to authenticated
using (public.is_admin() or public.is_service_role())
with check (public.is_admin() or public.is_service_role());

-- New notification preferences
create policy notification_preferences_select_own on public.notification_preferences
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notification_preferences_insert_own on public.notification_preferences
for insert to authenticated
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notification_preferences_update_own on public.notification_preferences
for update to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role())
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

-- New notification devices
create policy notification_devices_select_own on public.notification_devices
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notification_devices_insert_own on public.notification_devices
for insert to authenticated
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notification_devices_update_own on public.notification_devices
for update to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role())
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notification_devices_delete_own on public.notification_devices
for delete to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

-- New notifications inbox
create policy notifications_select_own on public.notifications
for select to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notifications_update_own on public.notifications
for update to authenticated
using (auth.uid() = user_id or public.is_admin() or public.is_service_role())
with check (auth.uid() = user_id or public.is_admin() or public.is_service_role());

create policy notifications_insert_admin on public.notifications
for insert to authenticated
with check (public.is_admin() or public.is_service_role());

create policy notifications_delete_admin on public.notifications
for delete to authenticated
using (public.is_admin() or public.is_service_role());

-- Internal notification tables: no client access policies on purpose.
-- service_role can still access them.
