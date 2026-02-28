export type PushSendResult = {
  enabled: boolean;
  attempted: number;
  success: number;
  failed: number;
  errors: string[];
};

type PushMessage = {
  title: string;
  body: string;
  data: Record<string, string>;
};

function sanitizeData(data: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    out[key] = String(value);
  }
  return out;
}

export async function sendPushToTokens(
  tokens: string[],
  message: PushMessage,
): Promise<PushSendResult> {
  const key = Deno.env.get('FCM_SERVER_KEY') ?? '';
  if (!key) {
    return {
      enabled: false,
      attempted: 0,
      success: 0,
      failed: 0,
      errors: ['FCM_SERVER_KEY not configured'],
    };
  }

  const cleanTokens = tokens.map((t) => t.trim()).filter((t) => t.length > 0);
  if (cleanTokens.length == 0) {
    return {
      enabled: true,
      attempted: 0,
      success: 0,
      failed: 0,
      errors: [],
    };
  }

  let success = 0;
  let failed = 0;
  const errors: string[] = [];
  const data = sanitizeData(message.data);

  for (const token of cleanTokens) {
    try {
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${key}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          priority: 'high',
          notification: {
            title: message.title,
            body: message.body,
          },
          data,
        }),
      });

      const json = await response.json().catch(() => ({}));
      const ok = response.ok &&
        Number((json?.success as number | undefined) ?? 0) > 0;

      if (ok) {
        success += 1;
      } else {
        failed += 1;
        errors.push(`token=${token.slice(0, 12)} status=${response.status}`);
      }
    } catch (error) {
      failed += 1;
      errors.push(
        error instanceof Error ? error.message : String(error),
      );
    }
  }

  return {
    enabled: true,
    attempted: cleanTokens.length,
    success,
    failed,
    errors,
  };
}
