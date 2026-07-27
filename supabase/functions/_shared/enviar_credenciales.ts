/**
 * Envía correo con saludo, correo y contraseña (nada más).
 * Usa el mismo mailer que `enviar-qr` / `reset-password`: Brevo.
 * Secret ya existente en el proyecto: BREVO_API_KEY.
 */
export async function enviarCredenciales(opts: {
  to: string;
  nombre: string;
  email: string;
  password: string;
}): Promise<void> {
  const apiKey = Deno.env.get("BREVO_API_KEY");
  if (!apiKey) {
    throw new Error("Falta el secreto BREVO_API_KEY en Supabase.");
  }

  const html =
    `<p>Hola ${escapeHtml(opts.nombre)},</p>` +
    `<p>Correo: ${escapeHtml(opts.email)}<br/>` +
    `Contraseña: ${escapeHtml(opts.password)}</p>`;

  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      accept: "application/json",
      "api-key": apiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      sender: {
        name: "Soporte Transworld",
        email: "no-reply@transworld.cl",
      },
      to: [{ email: opts.to }],
      subject: "Acceso Transworld Nexus",
      htmlContent: html,
    }),
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(
      `Brevo bloqueó el correo: ${(body as { message?: string }).message ?? res.status}`,
    );
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
