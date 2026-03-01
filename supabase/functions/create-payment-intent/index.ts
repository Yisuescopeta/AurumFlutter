import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';
import { stripe } from '../_shared/stripe.ts';

type ShippingData = {
  full_name: string;
  phone: string;
  address: string;
  city: string;
  postal_code: string;
};

type SingleItemPayload = {
  product_id: string;
  size: string;
  quantity: number;
  shipping: ShippingData;
};

type CartItemPayload = {
  product_id: string;
  size: string;
  quantity: number;
  name?: string;
  price?: number;
};

type CartPayload = {
  items: CartItemPayload[];
  coupon_code?: string;
  shipping: ShippingData;
};

const SHIPPING_COST = 500;

function splitInChunks(value: string, chunkSize = 450): string[] {
  const chunks: string[] = [];
  for (let i = 0; i < value.length; i += chunkSize) {
    chunks.push(value.slice(i, i + chunkSize));
  }
  return chunks;
}

async function validateCoupon(code: string, userId: string, cartTotal: number) {
  const normalizedCode = code.trim().toUpperCase();
  if (!normalizedCode) {
    return { valid: false, discountAmount: 0, couponId: null };
  }

  const { data: coupon, error } = await supabaseAdmin
    .from('coupons')
    .select('*')
    .eq('code', normalizedCode)
    .single();

  if (error || !coupon || !coupon.is_active) {
    return { valid: false, discountAmount: 0, couponId: null };
  }

  if (coupon.expiration_date && new Date(coupon.expiration_date) < new Date()) {
    return { valid: false, discountAmount: 0, couponId: null };
  }

  if (coupon.usage_limit) {
    const { count } = await supabaseAdmin
      .from('user_coupons')
      .select('*', { count: 'exact', head: true })
      .eq('coupon_id', coupon.id);

    if (count != null && count >= coupon.usage_limit) {
      return { valid: false, discountAmount: 0, couponId: null };
    }
  }

  if (coupon.is_single_use) {
    const { data: usage } = await supabaseAdmin
      .from('user_coupons')
      .select('id')
      .eq('coupon_id', coupon.id)
      .eq('user_id', userId)
      .maybeSingle();

    if (usage) {
      return { valid: false, discountAmount: 0, couponId: null };
    }
  }

  let discountAmount = 0;
  if (coupon.discount_type === 'percent') {
    discountAmount = Math.round((cartTotal * Number(coupon.discount_value || 0)) / 100);
  } else {
    discountAmount = Math.min(Math.round(Number(coupon.discount_value || 0) * 100), cartTotal);
  }

  return {
    valid: true,
    discountAmount,
    couponId: coupon.id as string,
    couponCode: normalizedCode,
  };
}

async function getValidatedSingleItem(body: SingleItemPayload) {
  const quantity = Math.max(1, Number(body.quantity || 1));

  const { data: product, error: productError } = await supabaseAdmin
    .from('products')
    .select('id,name,price,sale_price,is_on_sale,is_active')
    .eq('id', body.product_id)
    .eq('is_active', true)
    .single();

  if (productError || !product) {
    throw new Error('Producto no disponible');
  }

  const { data: variant, error: variantError } = await supabaseAdmin
    .from('product_variants')
    .select('size,stock')
    .eq('product_id', body.product_id)
    .eq('size', body.size)
    .single();

  if (variantError || !variant) {
    throw new Error('Talla no disponible');
  }

  const available = Number(variant.stock ?? 0);
  if (available < quantity) {
    throw new Error(`Stock insuficiente para talla ${body.size}`);
  }

  const unitPrice = product.is_on_sale && product.sale_price
    ? Number(product.sale_price)
    : Number(product.price);

  return {
    lines: [{
      product_id: body.product_id,
      product_name: String(product.name ?? ''),
      size: body.size,
      quantity,
      unit_price: unitPrice,
    }],
    discountAmount: 0,
    couponCode: '',
    couponId: '',
  };
}

async function getValidatedCart(body: CartPayload, userId: string) {
  if (!Array.isArray(body.items) || body.items.length == 0) {
    throw new Error('El carrito esta vacio');
  }

  const uniqueIds = [...new Set(body.items.map((i) => i.product_id).filter(Boolean))];
  const { data: products, error: productsError } = await supabaseAdmin
    .from('products')
    .select('id,name,price,sale_price,is_on_sale,is_active')
    .in('id', uniqueIds)
    .eq('is_active', true);

  if (productsError || !products) {
    throw new Error('No se pudieron validar productos');
  }

  const { data: variants, error: variantsError } = await supabaseAdmin
    .from('product_variants')
    .select('product_id,size,stock')
    .in('product_id', uniqueIds);

  if (variantsError || !variants) {
    throw new Error('No se pudieron validar tallas');
  }

  const productMap = new Map(products.map((p) => [String(p.id), p]));
  const stockMap = new Map<string, number>();
  for (const variant of variants) {
    stockMap.set(`${variant.product_id}::${variant.size}`, Number(variant.stock ?? 0));
  }

  const lines: Array<{
    product_id: string;
    product_name: string;
    size: string;
    quantity: number;
    unit_price: number;
  }> = [];

  let subtotal = 0;

  for (const item of body.items) {
    const productId = String(item.product_id || '').trim();
    const size = String(item.size || 'Unica').trim();
    const quantity = Math.max(1, Number(item.quantity || 1));
    const product = productMap.get(productId);

    if (!product) {
      throw new Error('Uno de los productos no esta disponible');
    }

    const available = stockMap.get(`${productId}::${size}`) ?? 0;
    if (available < quantity) {
      throw new Error(`Stock insuficiente para ${product.name} (${size})`);
    }

    const unitPrice = product.is_on_sale && product.sale_price
      ? Number(product.sale_price)
      : Number(product.price);

    subtotal += unitPrice * quantity;
    lines.push({
      product_id: productId,
      product_name: String(product.name ?? item.name ?? 'Producto'),
      size,
      quantity,
      unit_price: unitPrice,
    });
  }

  let discountAmount = 0;
  let couponCode = '';
  let couponId = '';
  if (body.coupon_code && body.coupon_code.trim() !== '') {
    const coupon = await validateCoupon(body.coupon_code, userId, subtotal);
    if (coupon.valid) {
      discountAmount = coupon.discountAmount;
      couponCode = coupon.couponCode ?? '';
      couponId = coupon.couponId ?? '';
    }
  }

  return { lines, discountAmount, couponCode, couponId };
}

Deno.serve(async (req: Request) => {
  if (req.method == 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method != 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace('Bearer ', '').trim();
    if (!token) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const body = await req.json() as SingleItemPayload | CartPayload;
    const shipping = (body as SingleItemPayload).shipping ?? (body as CartPayload).shipping;
    if (!shipping) {
      return jsonResponse({ error: 'Faltan datos de envio' }, 400);
    }

    const isCartCheckout = Array.isArray((body as CartPayload).items);
    const validated = isCartCheckout
      ? await getValidatedCart(body as CartPayload, user.id)
      : await getValidatedSingleItem(body as SingleItemPayload);

    const subtotal = validated.lines.reduce((sum, line) => sum + (line.unit_price * line.quantity), 0);
    const discountAmount = Math.max(0, Math.min(validated.discountAmount ?? 0, subtotal));
    const amount = (subtotal - discountAmount) + SHIPPING_COST;

    const compactItems = validated.lines.map((line) => ({
      p: line.product_id,
      n: line.product_name,
      s: line.size,
      q: line.quantity,
      u: line.unit_price,
    }));

    const compactJson = JSON.stringify(compactItems);
    const chunks = splitInChunks(compactJson);
    const metadata: Record<string, string> = {
      user_id: user.id,
      checkout_mode: isCartCheckout ? 'cart' : 'single',
      shipping_cost: String(SHIPPING_COST),
      shipping_full_name: shipping.full_name ?? '',
      shipping_phone: shipping.phone ?? '',
      shipping_address: shipping.address ?? '',
      shipping_city: shipping.city ?? '',
      shipping_postal_code: shipping.postal_code ?? '',
      discount_amount: String(discountAmount),
      coupon_code: validated.couponCode ?? '',
      coupon_id: validated.couponId ?? '',
      items_chunks: String(chunks.length),
    };

    // Backward compatibility for old single-item webhook data.
    if (compactItems.length == 1) {
      const line = compactItems[0];
      metadata.product_id = line.p;
      metadata.product_name = line.n;
      metadata.size = line.s;
      metadata.quantity = String(line.q);
      metadata.unit_price = String(line.u);
    }

    chunks.forEach((chunk, index) => {
      metadata[`items_${index}`] = chunk;
    });

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'eur',
      automatic_payment_methods: { enabled: true },
      receipt_email: user.email ?? undefined,
      metadata,
    });

    return jsonResponse({
      payment_intent_id: paymentIntent.id,
      payment_intent_client_secret: paymentIntent.client_secret,
      customer_email: user.email,
      amount,
      subtotal,
      discount_amount: discountAmount,
      shipping_cost: SHIPPING_COST,
      currency: 'eur',
    });
  } catch (error) {
    console.error('[create-payment-intent] error', error);
    const details = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: 'No se pudo iniciar el pago', details }, 500);
  }
});
