import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { supabaseAdmin } from '../_shared/supabaseAdmin.ts';

type RegisterDevicePayload = {
  fcm_token?: string;
  platform?: string;
  device_label?: string;
  app_version?: string;
};

function normalizePlatform(input: string | undefined): 'android' | 'ios' {
  if (input == 'ios') return 'ios';
  return 'android';
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

    const body = await req.json() as RegisterDevicePayload;
    const fcmToken = String(body.fcm_token ?? '').trim();
    if (!fcmToken) {
      return jsonResponse({ error: 'fcm_token is required' }, 400);
    }

    const nowIso = new Date().toISOString();
    const payload = {
      user_id: user.id,
      platform: normalizePlatform(body.platform),
      fcm_token: fcmToken,
      device_label: body.device_label ? String(body.device_label) : null,
      app_version: body.app_version ? String(body.app_version) : null,
      is_active: true,
      last_seen_at: nowIso,
      updated_at: nowIso,
    };

    const { error } = await supabaseAdmin
      .from('notification_devices')
      .upsert(payload, { onConflict: 'user_id,fcm_token' });

    if (error) {
      return jsonResponse(
        { error: 'No se pudo registrar dispositivo', details: error.message },
        500,
      );
    }

    return jsonResponse({ ok: true });
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: 'Unexpected error', details }, 500);
  }
});
