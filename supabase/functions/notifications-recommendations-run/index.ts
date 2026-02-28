import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import {
  createAndDispatchNotification,
} from '../_shared/notification_dispatch.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type ProductCandidate = {
  id: string;
  name: string;
  category_id: string;
  is_on_sale: boolean;
  created_at: string;
};

function assertCronAccess(req: Request): boolean {
  const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
  if (!cronSecret) return true;
  const header = req.headers.get('x-cron-secret') ?? '';
  return header.trim() == cronSecret.trim();
}

function dayKeyUtc(date = new Date()): string {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function scoreCandidates(
  items: ProductCandidate[],
  categoryScore: Map<string, number>,
): ProductCandidate[] {
  const copy = [...items];
  copy.sort((a, b) => {
    const aScore = (categoryScore.get(a.category_id) ?? 0) + (a.is_on_sale ? 1 : 0);
    const bScore = (categoryScore.get(b.category_id) ?? 0) + (b.is_on_sale ? 1 : 0);
    if (aScore != bScore) return bScore - aScore;
    return String(b.created_at).localeCompare(String(a.created_at));
  });
  return copy;
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
    const { data: usersRaw, error: usersError } = await supabaseAdmin
      .from('profiles')
      .select('id,role')
      .neq('role', 'admin');

    if (usersError || !usersRaw) {
      throw new Error(usersError?.message ?? 'Cannot load users');
    }

    let processed = 0;
    let sent = 0;
    let skipped = 0;

    for (const userRow of usersRaw) {
      const userId = String(userRow.id ?? '');
      if (!userId) continue;
      processed += 1;

      const categoryScore = new Map<string, number>();
      const favoriteProductIds = new Set<string>();

      const { data: favorites, error: favError } = await supabaseAdmin
        .from('favorites')
        .select('product_id, products(category_id,is_active)')
        .eq('user_id', userId);
      if (!favError && favorites) {
        for (const row of favorites) {
          const productId = String(row.product_id ?? '');
          if (productId) favoriteProductIds.add(productId);
          const relation = row.products;
          const product = Array.isArray(relation)
            ? (relation[0] as Record<string, unknown> | undefined)
            : (relation as Record<string, unknown> | null);
          if (!product || product.is_active == false) continue;
          const categoryId = String(product.category_id ?? '');
          if (!categoryId) continue;
          categoryScore.set(categoryId, (categoryScore.get(categoryId) ?? 0) + 3);
        }
      }

      const purchasedProductIds = new Set<string>();
      const { data: orders, error: ordersError } = await supabaseAdmin
        .from('orders')
        .select('id')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50);

      if (!ordersError && orders && orders.length > 0) {
        const orderIds = orders.map((o) => String(o.id ?? '')).filter((v) => v.length > 0);
        if (orderIds.length > 0) {
          const { data: orderItems, error: itemsError } = await supabaseAdmin
            .from('order_items')
            .select('product_id')
            .in('order_id', orderIds);
          if (!itemsError && orderItems) {
            for (const item of orderItems) {
              const productId = String(item.product_id ?? '');
              if (productId) purchasedProductIds.add(productId);
            }
          }
        }
      }

      if (purchasedProductIds.isNotEmpty) {
        const purchasedIds = [...purchasedProductIds];
        const { data: purchasedProducts, error: purchasedProductsError } = await supabaseAdmin
          .from('products')
          .select('id,category_id')
          .in('id', purchasedIds);
        if (!purchasedProductsError && purchasedProducts) {
          for (const product of purchasedProducts) {
            const categoryId = String(product.category_id ?? '');
            if (!categoryId) continue;
            categoryScore.set(categoryId, (categoryScore.get(categoryId) ?? 0) + 2);
          }
        }
      }

      if (categoryScore.isEmpty) {
        skipped += 1;
        continue;
      }

      const topCategories = [...categoryScore.entries()]
        .sort((a, b) => b[1] - a[1])
        .map((e) => e[0])
        .slice(0, 6);
      if (topCategories.length == 0) {
        skipped += 1;
        continue;
      }

      const { data: candidatesRaw, error: candidatesError } = await supabaseAdmin
        .from('products')
        .select('id,name,category_id,is_on_sale,created_at,is_active')
        .eq('is_active', true)
        .in('category_id', topCategories)
        .limit(120);

      if (candidatesError || !candidatesRaw) {
        skipped += 1;
        continue;
      }

      const baseCandidates: ProductCandidate[] = candidatesRaw
        .map((row) => ({
          id: String(row.id ?? ''),
          name: String(row.name ?? 'Producto'),
          category_id: String(row.category_id ?? ''),
          is_on_sale: row.is_on_sale == true,
          created_at: String(row.created_at ?? ''),
        }))
        .filter((p) =>
          p.id.length > 0 &&
          !favoriteProductIds.has(p.id) &&
          !purchasedProductIds.has(p.id)
        );

      if (baseCandidates.isEmpty) {
        skipped += 1;
        continue;
      }

      const candidateIds = baseCandidates.map((p) => p.id);
      const { data: variants, error: variantsError } = await supabaseAdmin
        .from('product_variants')
        .select('product_id,stock')
        .in('product_id', candidateIds);

      const stockByProduct = new Map<string, number>();
      if (!variantsError && variants) {
        for (const row of variants) {
          const productId = String(row.product_id ?? '');
          if (!productId) continue;
          const stock = Number(row.stock ?? 0);
          stockByProduct.set(productId, (stockByProduct.get(productId) ?? 0) + stock);
        }
      }

      const inStockCandidates = baseCandidates.filter((candidate) {
        return (stockByProduct.get(candidate.id) ?? 0) > 0;
      });
      if (inStockCandidates.isEmpty) {
        skipped += 1;
        continue;
      }

      const ranked = scoreCandidates(inStockCandidates, categoryScore);
      const top = ranked.slice(0, 3);
      if (top.isEmpty) {
        skipped += 1;
        continue;
      }

      const topProduct = top.first;
      const body = top.length == 1
        ? 'Creemos que ${topProduct.name} te podria gustar.'
        : 'Te recomendamos: ${top.map((p) => p.name).join(', ')}.';

      const dispatch = await createAndDispatchNotification({
        userId,
        type: 'recommendation',
        dedupeKey: `recommendation:${userId}:${dayKeyUtc()}`,
        title: 'Nuevas recomendaciones para ti',
        body,
        productId: topProduct.id,
        payload: {
          route: '/notifications',
          type: 'recommendation',
          product_ids: top.map((p) => p.id),
        },
      });

      if (dispatch.sent) {
        sent += 1;
      } else if (dispatch.status != 'duplicate') {
        skipped += 1;
      }
    }

    return jsonResponse({
      ok: true,
      processed_users: processed,
      sent,
      skipped,
    });
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    console.error('[notifications-recommendations-run] error', error);
    return jsonResponse({ error: 'Process failed', details }, 500);
  }
});
