-- Admin notifications module:
-- - adds "admin_broadcast" notification type
-- - adds editable templates for favorite discount notifications in site_settings

do $$
declare
  rec record;
begin
  if to_regclass('public.notifications') is not null then
    for rec in
      select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = 'notifications'
        and c.contype = 'c'
        and pg_get_constraintdef(c.oid) ilike '%type%'
        and pg_get_constraintdef(c.oid) ilike '%favorite_discount%'
        and pg_get_constraintdef(c.oid) ilike '%recommendation%'
    loop
      execute format('alter table public.notifications drop constraint %I', rec.conname);
    end loop;

    if not exists (
      select 1
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = 'notifications'
        and c.conname = 'notifications_type_check'
    ) then
      alter table public.notifications
      add constraint notifications_type_check
      check (type in ('favorite_discount', 'recommendation', 'admin_broadcast'));
    end if;
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

update public.site_settings
set
  favorite_discount_title_template = coalesce(
    nullif(trim(favorite_discount_title_template), ''),
    'Uno de tus favoritos esta en descuento'
  ),
  favorite_discount_body_template = coalesce(
    nullif(trim(favorite_discount_body_template), ''),
    '{{product_name}} ahora esta en oferta.'
  ),
  notification_updated_at = now()
where id = 'main';
