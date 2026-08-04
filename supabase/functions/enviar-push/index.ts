import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON",
);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type NotificacionRecord = {
  id: string;
  tipo: string;
  titulo: string;
  cuerpo: string;
  evento_id: string | null;
  registrado_id: string | null;
};

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;
  const bin = String.fromCharCode(...bytes);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const payload = base64UrlEncode(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;
  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`OAuth token error: ${err}`);
  }

  const tokenData = await tokenRes.json();
  return tokenData.access_token as string;
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  notificacion: NotificacionRecord,
): Promise<{ ok: boolean; invalidToken: boolean }> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: notificacion.titulo,
            body: notificacion.cuerpo,
          },
          data: {
            notificacion_id: notificacion.id,
            tipo: notificacion.tipo,
            evento_id: notificacion.evento_id ?? "",
            registrado_id: notificacion.registrado_id ?? "",
          },
        },
      }),
    },
  );

  if (res.ok) return { ok: true, invalidToken: false };

  const body = await res.text();
  const invalid = body.includes("UNREGISTERED") ||
    body.includes("INVALID_ARGUMENT") ||
    body.includes("NOT_FOUND");
  console.error(`FCM error for token ${token.slice(0, 12)}…: ${body}`);
  return { ok: false, invalidToken: invalid };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
      return json({ ok: false, skipped: true, reason: "no_firebase_config" });
    }

    const payload = await req.json();
    const record = (payload.record ?? payload) as NotificacionRecord;

    if (!record?.id || !record.titulo || !record.cuerpo) {
      return json({ ok: false, error: "invalid_payload" }, 400);
    }

    const account = JSON.parse(
      FIREBASE_SERVICE_ACCOUNT_JSON,
    ) as ServiceAccount;

    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("token");

    if (error) throw error;
    if (!tokens?.length) {
      return json({ ok: true, sent: 0, reason: "no_tokens" });
    }

    const accessToken = await getAccessToken(account);
    const invalidTokens: string[] = [];
    let sent = 0;

    for (const row of tokens) {
      const result = await sendFcmMessage(
        accessToken,
        account.project_id,
        row.token as string,
        record,
      );
      if (result.ok) {
        sent++;
      } else if (result.invalidToken) {
        invalidTokens.push(row.token as string);
      }
    }

    if (invalidTokens.length > 0) {
      await supabase.from("device_tokens").delete().in("token", invalidTokens);
    }

    return json({ ok: true, sent, invalid_removed: invalidTokens.length });
  } catch (e) {
    console.error("enviar-push error:", e);
    return json(
      { ok: false, error: e instanceof Error ? e.message : String(e) },
      500,
    );
  }
});
