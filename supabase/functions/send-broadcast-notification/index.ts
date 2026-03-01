import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import {
  createAndDispatchNotification,
} from '../_shared/notification_dispatch.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type BroadcastPayload = {
  title?: string;
  body?: string;
  route?: string;
  product_id?: string | null;
};

function normalizeRoute(input: unknown): string {
  const value = String(input ?? '').trim();
  if (!value) return '/notifications';
  return value.startsWith('/') ? value : '/notifications';
}

async function assertAdmin(token: string): Promise<string> {
  const {
    data: { user },
    error: userError,
  } = await supabaseAdmin.auth.getUser(token);

  if (userError || !user) {
    throw new Error('Unauthorized');
  }

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError || profile?.role != 'admin') {
    throw new Error('Forbidden');
  }

  return user.id;
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

    const adminId = await assertAdmin(token);
    const body = await req.json() as BroadcastPayload;

    const title = String(body.title ?? '').trim();
    const message = String(body.body ?? '').trim();
    const route = normalizeRoute(body.route);
    const productId = body.product_id ? String(body.product_id).trim() : null;

    if (!title || !message) {
      return jsonResponse({ error: 'title and body are required' }, 400);
    }

    const { data: recipients, error: recipientsError } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .neq('role', 'admin');

    if (recipientsError || !recipients) {
      return jsonResponse({ error: 'No se pudieron cargar destinatarios' }, 500);
    }

    const campaignKey = crypto.randomUUID();
    let sent = 0;
    let skipped = 0;
    let duplicates = 0;
    let failed = 0;

    for (const row of recipients) {
      const userId = String(row.id ?? '').trim();
      if (!userId) continue;

      const result = await createAndDispatchNotification({
        userId,
        type: 'admin_broadcast',
        dedupeKey: `admin_broadcast:${campaignKey}:${userId}`,
        title,
        body: message,
        productId: productId || null,
        payload: {
          route,
          type: 'admin_broadcast',
          admin_id: adminId,
        },
      });

      if (result.sent) {
        sent += 1;
      } else if (result.status == 'duplicate') {
        duplicates += 1;
      } else if (result.status == 'failed') {
        failed += 1;
      } else {
        skipped += 1;
      }
    }

    return jsonResponse({
      ok: true,
      total_recipients: recipients.length,
      sent,
      skipped,
      duplicates,
      failed,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message == 'Unauthorized') {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }
    if (message == 'Forbidden') {
      return jsonResponse({ error: 'Forbidden' }, 403);
    }
    console.error('[send-broadcast-notification] error', error);
    return jsonResponse({ error: 'No se pudo enviar la notificacion', details: message }, 500);
  }
});
