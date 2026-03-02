import { sendOrderInvoiceEmail } from './email.ts';
import { stripe } from './stripe.ts';
import { supabaseAdmin } from './supabaseAdmin.ts';

type CompactItem = {
  p: string;
  n: string;
  s: string;
  q: number;
  u: number;
};

type PaymentIntentLike = {
  id: string;
  amount_received?: number | null;
  receipt_email?: string | null;
  metadata?: Record<string, string | undefined>;
};

function makeTracking() {
  const rand = Math.random().toString(36).slice(2, 10).toUpperCase();
  return `AURUM-${rand}`;
}

function parseCompactItems(metadata: Record<string, string | undefined>): CompactItem[] {
  const chunksCount = Math.max(0, Number(metadata.items_chunks || '0'));
  if (chunksCount > 0) {
    let json = '';
    for (let i = 0; i < chunksCount; i++) {
      json += metadata[`items_${i}`] ?? '';
    }
    if (json) {
      try {
        const parsed = JSON.parse(json);
        if (Array.isArray(parsed)) {
          return parsed.map((item) => ({
            p: String(item.p || ''),
            n: String(item.n || 'Producto'),
            s: String(item.s || 'Unica'),
            q: Math.max(1, Number(item.q || 1)),
            u: Math.max(0, Number(item.u || 0)),
          }));
        }
      } catch (error) {
        console.error('[order-from-intent] cannot parse compact items', error);
      }
    }
  }

  // Backward compatibility with old single-item metadata.
  if (metadata.product_id) {
    return [{
      p: metadata.product_id,
      n: metadata.product_name || 'Producto',
      s: metadata.size || 'Unica',
      q: Math.max(1, Number(metadata.quantity || '1')),
      u: Math.max(0, Number(metadata.unit_price || '0')),
    }];
  }

  return [];
}

async function ensureProfileExists(userId: string, email: string, fullName: string) {
  const { data: existingProfile, error: profileReadError } = await supabaseAdmin
    .from('profiles')
    .select('id')
    .eq('id', userId)
    .maybeSingle();

  if (profileReadError) {
    throw new Error(`No se pudo consultar el perfil del usuario: ${profileReadError.message}`);
  }

  if (existingProfile?.id) return;

  const payload = {
    id: userId,
    email: email || null,
    full_name: fullName || null,
  };

  const { error: profileInsertError } = await supabaseAdmin
    .from('profiles')
    .upsert(payload, { onConflict: 'id' });

  if (profileInsertError) {
    throw new Error(`No se pudo crear el perfil del usuario: ${profileInsertError.message}`);
  }
}

async function decrementVariantStock(productId: string, size: string, quantity: number) {
  const { error: stockError } = await supabaseAdmin.rpc('decrement_variant_stock', {
    p_product_id: productId,
    p_size: size,
    p_quantity: quantity,
  });

  if (!stockError) return;

  // Fallback if RPC is missing or failing (supports duplicate rows per product/size).
  const { data: variants, error: variantsError } = await supabaseAdmin
    .from('product_variants')
    .select('id,stock')
    .eq('product_id', productId)
    .eq('size', size);

  if (variantsError || !variants || variants.length == 0) {
    throw new Error(`No se pudo leer stock de ${productId}/${size}: ${variantsError?.message}`);
  }

  const totalStock = variants.reduce((sum, variant) => sum + Math.max(0, Number(variant.stock ?? 0)), 0);
  if (totalStock < quantity) {
    throw new Error(`Stock insuficiente en decremento para ${productId}/${size}`);
  }

  let remaining = quantity;
  for (const variant of variants) {
    if (remaining <= 0) break;
    const currentStock = Math.max(0, Number(variant.stock ?? 0));
    if (currentStock <= 0) continue;

    const decrement = Math.min(currentStock, remaining);
    const { error: updateError } = await supabaseAdmin
      .from('product_variants')
      .update({ stock: currentStock - decrement })
      .eq('id', variant.id);

    if (updateError) {
      throw new Error(`No se pudo actualizar stock de ${productId}/${size}: ${updateError.message}`);
    }

    remaining -= decrement;
  }

  if (remaining > 0) {
    throw new Error(`No se pudo descontar todo el stock de ${productId}/${size}`);
  }
}

export async function ensureOrderFromPaymentIntent(intent: PaymentIntentLike): Promise<{
  orderId: string;
  created: boolean;
}> {
  const paymentIntentId = intent.id;
  console.log(`[order-from-intent] Processing intent: ${paymentIntentId}`);

  const { data: existing } = await supabaseAdmin
    .from('orders')
    .select('id')
    .eq('payment_intent_id', paymentIntentId)
    .maybeSingle();

  if (existing?.id) {
    console.log(`[order-from-intent] Order already exists: ${existing.id}`);
    return { orderId: String(existing.id), created: false };
  }

  const md = intent.metadata ?? {};
  const userId = md.user_id || null;
  const compactItems = parseCompactItems(md);

  if (!userId || !intent.amount_received || compactItems.length == 0) {
    console.error('[order-from-intent] Missing metadata', { userId, amount: intent.amount_received, items: compactItems.length });
    throw new Error('Missing metadata required for order creation');
  }

  const shippingAddress = md.shipping_address || 'No especificada';
  const shippingCity = md.shipping_city || 'No especificada';
  const shippingPostal = md.shipping_postal_code || '00000';
  const shippingPhone = md.shipping_phone || null;
  const fullName = md.shipping_full_name || 'Cliente';
  const shippingCost = parseInt(md.shipping_cost || '0', 10);
  const couponId = md.coupon_id || null;

  const customerEmail = intent.receipt_email || '';
  await ensureProfileExists(userId, customerEmail, fullName);

  const orderInsert = {
    user_id: userId,
    customer_email: customerEmail,
    total_amount: intent.amount_received,
    shipping_cost: shippingCost,
    status: 'paid',
    shipping_address: shippingAddress,
    shipping_city: shippingCity,
    shipping_postal_code: shippingPostal,
    shipping_phone: shippingPhone,
    notes: `Destinatario: ${fullName}`,
    tracking_number: makeTracking(),
    payment_intent_id: paymentIntentId,
  };

  console.log('[order-from-intent] Inserting order...', orderInsert);
  const { data: order, error: orderError } = await supabaseAdmin
    .from('orders')
    .insert(orderInsert)
    .select('id,tracking_number,total_amount')
    .single();

  if (orderError || !order) {
    console.error('[order-from-intent] Order insert error:', orderError);
    throw new Error(`Failed to insert order: ${orderError?.message}`);
  }
  console.log(`[order-from-intent] Order created: ${order.id}`);

  // Validate stock before inserting items.
  for (const item of compactItems) {
    const { data: variants, error: variantError } = await supabaseAdmin
      .from('product_variants')
      .select('stock')
      .eq('product_id', item.p)
      .eq('size', item.s);

    const availableStock = Array.isArray(variants)
      ? variants.reduce((sum, variant) => sum + Math.max(0, Number(variant.stock ?? 0)), 0)
      : 0;

    if (variantError || !variants || variants.length == 0 || availableStock < item.q) {
      console.warn(`[order-from-intent] Stock failure for ${item.n}. Refunding...`);
      await stripe.refunds.create({ payment_intent: paymentIntentId });
      await supabaseAdmin
        .from('orders')
        .update({
          status: 'refunded',
          refund_status: 'pending', // Use 'pending' as per new constraints
          refunded_at: new Date().toISOString(),
        })
        .eq('id', order.id);
      throw new Error(`Stock not available for ${item.n} (${item.s}). Refund processed.`);
    }
  }

  const orderItems = compactItems.map((item) => ({
    order_id: order.id,
    product_name: `${item.n} (${item.s})`,
    product_id: item.p,
    quantity: item.q,
    price_at_purchase: item.u,
    size: item.s,
  }));

  const { error: itemError } = await supabaseAdmin.from('order_items').insert(orderItems);
  if (itemError) {
    console.error('[order-from-intent] Item insert error:', itemError);
    throw new Error(`Failed to insert order items: ${itemError.message}`);
  }

  const { error: historyError } = await supabaseAdmin.from('order_status_history').insert({
    order_id: order.id,
    status: 'paid',
    notes: 'Pago confirmado por Stripe',
    created_by: userId,
  });
  if (historyError) {
    console.error('[order-from-intent] history insert error:', historyError);
  }

  for (const item of compactItems) {
    await decrementVariantStock(item.p, item.s, item.q);
  }

  const shippingText = `${shippingAddress}, ${shippingPostal} ${shippingCity}`;
  try {
    await sendOrderInvoiceEmail({
      to: customerEmail,
      orderId: order.id,
      customerName: fullName,
      totalAmount: order.total_amount,
      trackingNumber: order.tracking_number ?? '-',
      shippingAddress: shippingText,
      items: compactItems.map((item) => ({
        name: `${item.n} (Talla: ${item.s})`,
        quantity: item.q,
        unitPrice: item.u,
      })),
      shippingCost,
    });
  } catch (emailError) {
    console.error('[order-from-intent] email send error', emailError);
  }

  if (couponId) {
    const { error: couponUsageError } = await supabaseAdmin.from('user_coupons').insert({
      user_id: userId,
      coupon_id: couponId,
      used_at: new Date().toISOString(),
    });
    if (couponUsageError) {
      console.error('[order-from-intent] coupon usage error', couponUsageError);
    }
  }

  return { orderId: String(order.id), created: true };
}
