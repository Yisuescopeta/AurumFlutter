import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import {
  createAndDispatchNotification,
} from '../_shared/notification_dispatch.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type ProductRow = {
  id: string;
  name: string;
  is_on_sale: boolean;
  sale_price: number | null;
};

type SaleStateRow = {
  product_id: string;
  last_is_on_sale: boolean;
  last_sale_price: number | null;
};

type TriggerKind = 'entry_to_sale' | 'price_drop';

function assertCronAccess(req: Request): boolean {
  const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
  if (!cronSecret) return true;
  const header = req.headers.get('x-cron-secret') ?? '';
  return header.trim() == cronSecret.trim();
}

function toProductRow(raw: Record<string, unknown>): ProductRow {
  return {
    id: String(raw.id ?? ''),
    name: String(raw.name ?? 'Producto'),
    is_on_sale: raw.is_on_sale == true,
    sale_price: raw.sale_price == null ? null : Number(raw.sale_price),
  };
}

function isPositiveNumber(value: number | null): boolean {
  return value != null && Number.isFinite(value) && value > 0;
}

Deno.serve(async (req: Request) => {
  if (req.method == 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method != 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }
  if (!assertCronAccess(req)) {
    return jsonResponse({ error: 'Forbidden' }, 403);
  }

  try {
    const { data: productsRaw, error: productsError } = await supabaseAdmin
      .from('products')
      .select('id,name,is_on_sale,sale_price')
      .eq('is_active', true);

    if (productsError || !productsRaw) {
      throw new Error(productsError?.message ?? 'Cannot load products');
    }

    const { data: statesRaw, error: statesError } = await supabaseAdmin
      .from('notification_product_sale_state')
      .select('product_id,last_is_on_sale,last_sale_price');
    if (statesError) {
      throw new Error(statesError.message);
    }

    const products = (productsRaw as Record<string, unknown>[])
      .map(toProductRow)
      .filter((p) => p.id.length > 0);
    const states = (statesRaw ?? []) as SaleStateRow[];
    const stateMap = new Map(states.map((s) => [s.product_id, s]));

    const baselineProducts = products.filter((product) => !stateMap.has(product.id));
    const triggerProducts: Array<{ product: ProductRow; trigger: TriggerKind }> = [];

    for (const product of products) {
      const prev = stateMap.get(product.id);
      if (!prev) continue; // baseline: initialize state only, no send

      // Trigger 1: product enters sale.
      if (prev.last_is_on_sale == false && product.is_on_sale == true) {
        if (isPositiveNumber(product.sale_price)) {
          triggerProducts.push({ product, trigger: 'entry_to_sale' });
        }
        continue;
      }

      // Trigger 2: product is already on sale and sale price drops further.
      if (
        prev.last_is_on_sale == true &&
        product.is_on_sale == true &&
        isPositiveNumber(prev.last_sale_price) &&
        isPositiveNumber(product.sale_price) &&
        Number(product.sale_price) < Number(prev.last_sale_price)
      ) {
        triggerProducts.push({ product, trigger: 'price_drop' });
      }
    }

    let candidates = 0;
    let sent = 0;
    let skipped = 0;
    let duplicates = 0;

    for (const item of triggerProducts) {
      const product = item.product;
      const { data: favorites, error: favoritesError } = await supabaseAdmin
        .from('favorites')
        .select('user_id')
        .eq('product_id', product.id);

      if (favoritesError || !favorites) {
        continue;
      }

      const users = [...new Set(
        favorites.map((f) => String(f.user_id ?? '')).filter((u) => u.length > 0),
      )];
      candidates += users.length;

      for (const userId of users) {
        const dedupeKey = `favorite_discount:${product.id}:${product.sale_price ?? 'sale'}`;
        const result = await createAndDispatchNotification({
          userId,
          type: 'favorite_discount',
          dedupeKey,
          title: 'Uno de tus favoritos esta en descuento',
          body: `${product.name} acaba de entrar en oferta.`,
          productId: product.id,
          payload: {
            route: '/product-detail',
            product_id: product.id,
            type: 'favorite_discount',
            trigger: item.trigger,
          },
        });

        if (result.sent) {
          sent += 1;
        } else if (result.status == 'duplicate') {
          duplicates += 1;
        } else if (result.status != 'duplicate') {
          skipped += 1;
        }
      }
    }

    const upsertRows = products.map((p) => ({
      product_id: p.id,
      last_is_on_sale: p.is_on_sale,
      last_sale_price: p.sale_price,
      updated_at: new Date().toISOString(),
    }));

    if (upsertRows.length > 0) {
      await supabaseAdmin
        .from('notification_product_sale_state')
        .upsert(upsertRows, { onConflict: 'product_id' });
    }

    const changedToSale = triggerProducts.filter((t) => t.trigger == 'entry_to_sale').length;
    const priceDrops = triggerProducts.filter((t) => t.trigger == 'price_drop').length;

    console.info('[notifications-discount-favorites-run] summary', {
      scanned_products: products.length,
      baseline_count: baselineProducts.length,
      changed_to_sale: changedToSale,
      price_drops: priceDrops,
      target_users: candidates,
      sent,
      skipped,
      duplicates,
    });

    return jsonResponse({
      ok: true,
      scanned_products: products.length,
      baseline_count: baselineProducts.length,
      changed_to_sale: changedToSale,
      price_drops: priceDrops,
      target_users: candidates,
      sent,
      skipped,
      duplicates,
    });
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    console.error('[notifications-discount-favorites-run] error', error);
    return jsonResponse({ error: 'Process failed', details }, 500);
  }
});
