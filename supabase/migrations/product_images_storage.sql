-- Product images storage setup
-- Public read, admin/service write

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update
set public = excluded.public,
    name = excluded.name;

alter table storage.objects enable row level security;

drop policy if exists "Public read product images" on storage.objects;
create policy "Public read product images"
on storage.objects
for select
to public
using (bucket_id = 'product-images');

drop policy if exists "Admin upload product images" on storage.objects;
create policy "Admin upload product images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (
    coalesce(auth.jwt()->>'role', '') = 'service_role'
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  )
);

drop policy if exists "Admin update product images" on storage.objects;
create policy "Admin update product images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'product-images'
  and (
    coalesce(auth.jwt()->>'role', '') = 'service_role'
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  )
)
with check (
  bucket_id = 'product-images'
  and (
    coalesce(auth.jwt()->>'role', '') = 'service_role'
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  )
);

drop policy if exists "Admin delete product images" on storage.objects;
create policy "Admin delete product images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (
    coalesce(auth.jwt()->>'role', '') = 'service_role'
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  )
);
