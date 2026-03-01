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

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type AccessTokenState = {
  token: string;
  expiresAtMs: number;
};

let cachedAccessToken: AccessTokenState | null = null;

function sanitizeData(data: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    out[key] = String(value);
  }
  return out;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary);
}

function base64UrlEncodeString(value: string): string {
  const encoded = bytesToBase64(new TextEncoder().encode(value));
  return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function base64UrlEncodeBytes(value: Uint8Array): string {
  const encoded = bytesToBase64(value);
  return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function pemToPkcs8Bytes(pem: string): Uint8Array {
  const normalized = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(normalized);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function readServiceAccountFromEnv(): ServiceAccount | null {
  const raw = (Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '').trim();
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw) as Partial<ServiceAccount>;
    const projectId = String(parsed.project_id ?? '').trim();
    const clientEmail = String(parsed.client_email ?? '').trim();
    const privateKeyRaw = String(parsed.private_key ?? '').trim();
    const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) return null;
    return {
      project_id: projectId,
      client_email: clientEmail,
      private_key: privateKey,
    };
  } catch (_) {
    return null;
  }
}

async function signJwtRs256(payload: {
  iss: string;
  scope: string;
  aud: string;
  iat: number;
  exp: number;
}, privateKeyPem: string): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const encodedHeader = base64UrlEncodeString(JSON.stringify(header));
  const encodedPayload = base64UrlEncodeString(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8Bytes(privateKeyPem),
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );

  const encodedSignature = base64UrlEncodeBytes(new Uint8Array(signature));
  return `${signingInput}.${encodedSignature}`;
}

async function getFcmAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Date.now();
  if (cachedAccessToken && cachedAccessToken.expiresAtMs > now + 10_000) {
    return cachedAccessToken.token;
  }

  const iat = Math.floor(now / 1000);
  const exp = iat + 3500;
  const assertion = await signJwtRs256(
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat,
      exp,
    },
    serviceAccount.private_key,
  );

  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body.toString(),
  });

  if (!response.ok) {
    const details = await response.text().catch(() => '');
    throw new Error(`FCM access token error (${response.status}): ${details}`);
  }

  const json = await response.json() as {
    access_token?: string;
    expires_in?: number;
  };

  const token = String(json.access_token ?? '').trim();
  if (!token) {
    throw new Error('FCM access token missing in OAuth response');
  }

  const expiresInSec = Number(json.expires_in ?? 3600);
  cachedAccessToken = {
    token,
    expiresAtMs: now + ((expiresInSec - 60) * 1000),
  };

  return token;
}

async function sendWithFcmV1(
  tokens: string[],
  message: PushMessage,
  serviceAccount: ServiceAccount,
): Promise<PushSendResult> {
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

  const data = sanitizeData(message.data);
  const projectId = serviceAccount.project_id;
  let success = 0;
  let failed = 0;
  const errors: string[] = [];

  for (const token of cleanTokens) {
    try {
      const accessToken = await getFcmAccessToken(serviceAccount);
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: {
                title: message.title,
                body: message.body,
              },
              data,
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: 'aurum_notifications',
                  sound: 'default',
                },
              },
            },
          }),
        },
      );

      if (response.ok) {
        success += 1;
      } else {
        failed += 1;
        const details = await response.text().catch(() => '');
        errors.push(
          `token=${token.slice(0, 12)} status=${response.status} ${details}`,
        );
      }
    } catch (error) {
      failed += 1;
      errors.push(error instanceof Error ? error.message : String(error));
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

async function sendWithLegacyKey(
  tokens: string[],
  message: PushMessage,
  key: string,
): Promise<PushSendResult> {
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
      errors.push(error instanceof Error ? error.message : String(error));
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

export async function sendPushToTokens(
  tokens: string[],
  message: PushMessage,
): Promise<PushSendResult> {
  const serviceAccount = readServiceAccountFromEnv();
  if (serviceAccount) {
    return await sendWithFcmV1(tokens, message, serviceAccount);
  }

  const key = (Deno.env.get('FCM_SERVER_KEY') ?? '').trim();
  if (key) {
    return await sendWithLegacyKey(tokens, message, key);
  }

  return {
    enabled: false,
    attempted: 0,
    success: 0,
    failed: 0,
    errors: [
      'Push not configured: set FCM_SERVICE_ACCOUNT_JSON (recommended) or FCM_SERVER_KEY',
    ],
  };
}
