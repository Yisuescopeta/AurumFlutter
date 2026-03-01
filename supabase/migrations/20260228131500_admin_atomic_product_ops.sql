-- Atomic admin operations for product variants/stock and safe product delete.

create or replace function public.admin_upsert_product_variants_and_stock(
  p_product_id uuid,
  p_variants jsonb default '[]'::jsonb
)
returns void
language plpgsql
as $$
begin
  if not (public.is_admin() or public.is_service_role()) then
    raise exception 'No autorizado';
  end if;

  perform 1
    from public.products
   where id = p_product_id
   for update;

  if not found then
    raise exception 'Producto no encontrado';
  end if;

  delete from public.product_variants
   where product_id = p_product_id;

  if jsonb_typeof(coalesce(p_variants, '[]'::jsonb)) = 'array'
     and jsonb_array_length(coalesce(p_variants, '[]'::jsonb)) > 0 then
    insert into public.product_variants (product_id, size, stock, sku_variant)
    select
      p_product_id,
      trim(v.size),
      greatest(coalesce(v.stock, 0), 0),
      nullif(trim(coalesce(v.sku_variant, '')), '')
    from jsonb_to_recordset(p_variants) as v(
      size text,
      stock integer,
      sku_variant text
    )
    where nullif(trim(coalesce(v.size, '')), '') is not null;
  end if;

  update public.products p
     set stock = coalesce((
       select sum(pv.stock)
         from public.product_variants pv
        where pv.product_id = p.id
     ), 0)
   where p.id = p_product_id;
end;
$$;

create or replace function public.admin_delete_product_if_no_orders(
  p_product_id uuid
)
returns void
language plpgsql
as $$
declare
  v_has_orders boolean;
begin
  if not (public.is_admin() or public.is_service_role()) then
    raise exception 'No autorizado';
  end if;

  perform 1
    from public.products
   where id = p_product_id
   for update;

  if not found then
    raise exception 'Producto no encontrado';
  end if;

  select exists(
    select 1
      from public.order_items
     where product_id = p_product_id
  )
  into v_has_orders;

  if v_has_orders then
    raise exception 'No se puede eliminar: este producto tiene pedidos asociados.';
  end if;

  delete from public.products
   where id = p_product_id;
end;
$$;

grant execute on function public.admin_upsert_product_variants_and_stock(uuid, jsonb)
to authenticated, service_role;

grant execute on function public.admin_delete_product_if_no_orders(uuid)
to authenticated, service_role;
