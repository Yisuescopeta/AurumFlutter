-- Advanced notifications schema for Aurum (run on the cloned DB, not production).
-- This script only adds notification-related tables and policies.

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

create index if not exists idx_notification_devices_user_active
  on public.notification_devices(user_id, is_active);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('favorite_discount', 'recommendation', 'admin_broadcast')),
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

create index if not exists idx_notifications_user_created
  on public.notifications(user_id, created_at desc);

create index if not exists idx_notifications_user_unread
  on public.notifications(user_id, is_read);

create table if not exists public.notification_product_sale_state (
  product_id uuid primary key references public.products(id) on delete cascade,
  last_is_on_sale boolean not null,
  last_sale_price integer null,
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_dispatch_log (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid null references public.notifications(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  dedupe_key text not null,
  status text not null check (status in ('sent', 'skipped_daily_cap', 'skipped_quiet_hours', 'skipped_disabled', 'failed')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_notification_dispatch_user_day
  on public.notification_dispatch_log(user_id, created_at desc);

create unique index if not exists uq_notification_dispatch_dedupe
  on public.notification_dispatch_log(user_id, dedupe_key);

alter table public.notification_preferences enable row level security;
alter table public.notification_devices enable row level security;
alter table public.notifications enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_select_own'
  ) then
    create policy notifications_select_own
      on public.notifications for select
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_update_own'
  ) then
    create policy notifications_update_own
      on public.notifications for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notification_preferences'
      and policyname = 'notification_preferences_rw_own'
  ) then
    create policy notification_preferences_rw_own
      on public.notification_preferences for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notification_devices'
      and policyname = 'notification_devices_rw_own'
  ) then
    create policy notification_devices_rw_own
      on public.notification_devices for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

alter table if exists public.site_settings
  add column if not exists favorite_discount_title_template text,
  add column if not exists favorite_discount_body_template text,
  add column if not exists notification_updated_at timestamptz not null default now();

insert into public.site_settings (
  id,
  favorite_discount_title_template,
  favorite_discount_body_template
)
values (
  'main',
  'Uno de tus favoritos esta en descuento',
  '{{product_name}} ahora esta en oferta.'
)
on conflict (id) do nothing;
