-- Add returned order status and normalize refund status values.

update public.orders
set refund_status = 'pending'
where refund_status = 'requested';

do $$
declare
  c_name text;
begin
  select conname into c_name
  from pg_constraint
  where conrelid = 'public.orders'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%status in (%pending%paid%confirmed%processing%shipped%delivered%cancelled%refunded%';

  if c_name is not null then
    execute format('alter table public.orders drop constraint %I', c_name);
  end if;
end $$;

alter table public.orders
  add constraint orders_status_check
  check (
    status in (
      'pending',
      'paid',
      'confirmed',
      'processing',
      'shipped',
      'delivered',
      'cancelled',
      'refunded',
      'returned'
    )
  );

do $$
declare
  c_name text;
begin
  select conname into c_name
  from pg_constraint
  where conrelid = 'public.orders'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%refund_status%';

  if c_name is not null then
    execute format('alter table public.orders drop constraint %I', c_name);
  end if;
end $$;

alter table public.orders
  add constraint orders_refund_status_check
  check (refund_status in ('pending', 'completed', 'failed'));

create index if not exists idx_orders_status on public.orders(status);
