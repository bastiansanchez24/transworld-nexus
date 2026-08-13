/**
 * Envío transaccional vía Brevo, con cabeceras para que Outlook
 * lo trate como prioritario (bandeja Prioritarios, no "Otros").
 *
 * Remitentes:
 * - `soporte@` — casos internos (credenciales, reset, alta de usuario).
 * - `contacto@` — QR de eventos y comunicaciones a asistentes.
 *
 * Brevo solo reenvía cabeceras no estándar; X-Priority / X-MSMail-Priority
 * son las que Outlook lee para marcar importancia alta.
 */
export const cabecerasPrioridadOutlook: Record<string, string> = {
  "X-Priority": "1",
  "X-MSMail-Priority": "High",
};

export const remitenteSoporte = {
  name: "Soporte Transworld",
  email: "soporte@transworld.cl",
} as const;

export const remitenteContacto = {
  name: "Transworld",
  email: "contacto@transworld.cl",
} as const;

type Remitente = { name: string; email: string };

export async function enviarCorreoBrevo(
  payload: Record<string, unknown>,
): Promise<Response> {
  const apiKey = Deno.env.get("BREVO_API_KEY");
  if (!apiKey) {
    throw new Error("Falta el secreto BREVO_API_KEY en Supabase.");
  }

  const headersExtra = (payload.headers ?? {}) as Record<string, string>;
  const sender = payload.sender as Remitente | undefined;
  return await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      accept: "application/json",
      "api-key": apiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      ...payload,
      replyTo: payload.replyTo ?? sender ?? remitenteSoporte,
      headers: {
        ...cabecerasPrioridadOutlook,
        ...headersExtra,
      },
      tags: [
        "transactional",
        ...((payload.tags as string[] | undefined) ?? []),
      ],
    }),
  });
}
