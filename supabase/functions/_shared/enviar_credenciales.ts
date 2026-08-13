import {
  enviarCorreoBrevo,
  remitenteSoporte,
} from "./brevo.ts";

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
  const html =
    `<p>Hola ${escapeHtml(opts.nombre)},</p>` +
    `<p>Correo: ${escapeHtml(opts.email)}<br/>` +
    `Contraseña: ${escapeHtml(opts.password)}</p>`;
  const texto =
    `Hola ${opts.nombre},\n\n` +
    `Correo: ${opts.email}\n` +
    `Contraseña: ${opts.password}\n`;

  const res = await enviarCorreoBrevo({
    sender: remitenteSoporte,
    replyTo: remitenteSoporte,
    to: [{ email: opts.to, name: opts.nombre }],
    subject: "Acceso Transworld Nexus",
    htmlContent: html,
    textContent: texto,
    tags: ["credenciales"],
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
