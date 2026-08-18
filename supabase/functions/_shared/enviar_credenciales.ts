import { enviarCorreoBrevo, remitenteSoporte } from "./brevo.ts";
import {
  asuntoCredenciales,
  htmlCredenciales,
  type MotivoCredenciales,
  textoCredenciales,
} from "./plantilla_credenciales.ts";

/**
 * Envía el correo con las credenciales de acceso a RegisPro.
 * Usa el mismo mailer que `enviar-qr` / `reset-password`: Brevo.
 * Secret ya existente en el proyecto: BREVO_API_KEY.
 */
export async function enviarCredenciales(opts: {
  to: string;
  nombre: string;
  email: string;
  password: string;
  /** Rol de `perfiles.rol`; si se omite no se muestra el perfil asignado. */
  rol?: string | null;
  /** Por defecto, alta de cuenta nueva. */
  motivo?: MotivoCredenciales;
}): Promise<void> {
  const motivo = opts.motivo ?? "cuenta_nueva";
  const datos = {
    nombre: opts.nombre,
    email: opts.email,
    password: opts.password,
    rol: opts.rol,
    motivo,
  };

  const res = await enviarCorreoBrevo({
    sender: remitenteSoporte,
    replyTo: remitenteSoporte,
    to: [{ email: opts.to, name: opts.nombre }],
    subject: asuntoCredenciales(motivo),
    htmlContent: htmlCredenciales(datos),
    textContent: textoCredenciales(datos),
    tags: ["credenciales", motivo],
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(
      `Brevo bloqueó el correo: ${
        (body as { message?: string }).message ?? res.status
      }`,
    );
  }
}
