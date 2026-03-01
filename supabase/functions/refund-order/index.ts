import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';
import { stripe } from '../_shared/stripe.ts';

function mapStripeRefundStatus(status: string | null | undefined): 'pending' | 'completed' | 'failed' {
    if (status === 'succeeded') return 'completed';
    if (status === 'pending') return 'pending';
    return 'failed';
}

function computeRefundRule(status: string, totalAmount: number, shippingCost: number) {
    if (status === 'paid') {
        return {
            refundAmount: totalAmount,
            shippingRefunded: true,
            finalStatus: 'refunded',
            userMessage: 'Reembolso completo (incluye envio).',
        } as const;
    }

    if (status === 'confirmed' || status === 'processing' || status === 'shipped') {
        return {
            refundAmount: totalAmount - shippingCost,
            shippingRefunded: false,
            finalStatus: 'cancelled',
            userMessage: 'Pedido cancelado con reembolso sin gastos de envio.',
        } as const;
    }

    if (status === 'delivered') {
        return {
            refundAmount: totalAmount - shippingCost,
            shippingRefunded: false,
            finalStatus: 'returned',
            userMessage: 'Pedido devuelto con reembolso sin gastos de envio.',
        } as const;
    }

    return null;
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
            return jsonResponse({ error: 'Unauthorized: No token provided' }, 401);
        }

        const {
            data: { user },
            error: userError,
        } = await supabaseAdmin.auth.getUser(token);

        if (userError || !user) {
            return jsonResponse({ error: 'Unauthorized: Invalid or expired token' }, 401);
        }

        const body = await req.json();
        const orderId = body.order_id;

        if (!orderId) {
            return jsonResponse({ error: 'Missing order_id' }, 400);
        }

        const { data: order, error: orderError } = await supabaseAdmin
            .from('orders')
            .select('id, user_id, status, payment_intent_id, total_amount, shipping_cost')
            .eq('id', orderId)
            .single();

        if (orderError || !order) {
            return jsonResponse({ error: 'Order not found' }, 404);
        }

        if (order.user_id !== user.id) {
            return jsonResponse({ error: 'Unauthorized to refund this order' }, 403);
        }

        const totalAmount = Number(order.total_amount ?? 0);
        const shippingCost = Number(order.shipping_cost ?? 0);
        const rule = computeRefundRule(order.status, totalAmount, shippingCost);
        if (!rule) {
            return jsonResponse({ error: 'Order cannot be refunded' }, 400);
        }

        if (!order.payment_intent_id) {
            return jsonResponse({ error: 'Cannot refund order without payment intent' }, 400);
        }

        const refundAmount = rule.refundAmount;
        if (refundAmount <= 0) {
            return jsonResponse({ error: 'Nothing to refund' }, 400);
        }

        const stripeRefund = await stripe.refunds.create({
            payment_intent: order.payment_intent_id,
            amount: refundAmount,
        });

        await supabaseAdmin
            .from('orders')
            .update({
                status: rule.finalStatus,
                refund_status: mapStripeRefundStatus(stripeRefund.status),
                refunded_at: new Date().toISOString(),
                cancelled_at: rule.finalStatus === 'cancelled' ? new Date().toISOString() : null,
            })
            .eq('id', orderId);

        await supabaseAdmin.from('order_status_history').insert({
            order_id: order.id,
            status: rule.finalStatus,
            notes: `${rule.userMessage} Importe: ${(refundAmount / 100).toFixed(2)} EUR`,
            created_by: user.id,
        });

        const { data: items } = await supabaseAdmin
            .from('order_items')
            .select('product_id, size, quantity')
            .eq('order_id', order.id);

        if (items && items.length > 0) {
            for (const item of items) {
                if (item.product_id && item.size && item.quantity) {
                    await supabaseAdmin.rpc('increment_variant_stock', {
                        p_product_id: item.product_id,
                        p_size: item.size,
                        p_quantity: item.quantity,
                    });
                }
            }
        }

        return jsonResponse({
            success: true,
            refund: stripeRefund.id,
            refund_amount: refundAmount,
            shipping_refunded: rule.shippingRefunded,
            final_status: rule.finalStatus,
        });
    } catch (error) {
        console.error('[refund-order] error', error);
        const details = error instanceof Error ? error.message : String(error);
        return jsonResponse({ error: 'No se pudo procesar la devolucion', details }, 500);
    }
});
