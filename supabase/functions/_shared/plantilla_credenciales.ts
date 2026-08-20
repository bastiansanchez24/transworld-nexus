import { LARGO_MINIMO_PASSWORD } from "./password.ts";

/**
 * Plantilla del correo de credenciales de RegisPro (diseño "Correo
 * Credenciales RegisPro").
 *
 * Es HTML de correo, no HTML de web: tablas anidadas de 600px, estilos en
 * línea, `mso-line-height-rule` y el bloque condicional de Office para que
 * Outlook no reescale la tipografía. No usar flexbox/grid acá.
 */

/** Motivo del envío; cambia epígrafe, titular, preheader y asunto. */
export type MotivoCredenciales = "cuenta_nueva" | "password_restablecida";

export interface DatosCredenciales {
  nombre: string;
  email: string;
  password: string;
  /** Rol tal como se guarda en `perfiles.rol`. Omitido = no se muestra. */
  rol?: string | null;
  motivo?: MotivoCredenciales;
  /**
   * SemVer de la app del emisor (`1.6.8`). El APK del correo apunta a esa
   * Release. Omitido = `/releases/latest`.
   */
  versionApp?: string | null;
}

/** Panel web de administración (ver comentario en `lib/core/config/env.dart`). */
const URL_PANEL = "https://regispro.transworld.cl/";

const GITHUB_OWNER = "bsanchezTW";
const GITHUB_REPO = "transworld-nexus";

/** `v1.6.8` / `1.6.8+27` → `1.6.8`. */
export function normalizarVersionApp(
  raw: string | null | undefined,
): string | null {
  const match = String(raw ?? "").trim().match(/^v?(\d+\.\d+\.\d+)/i);
  return match ? match[1] : null;
}

/** APK de la misma versión que el emisor, o la última Release si no hay. */
export function urlDescargaAndroid(versionRaw?: string | null): string {
  const version = normalizarVersionApp(versionRaw);
  if (!version) {
    return `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;
  }
  return `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/v${version}/android-regispro-v${version}.apk`;
}

/** Mismo buzón que muestra la pantalla de login (`login_screen.dart`). */
const SOPORTE_EMAIL = "soporte@transworld.cl";

/** Espejo de `AppRole.label` en `lib/core/constants/app_role.dart`. */
const ETIQUETAS_ROL: Record<string, string> = {
  admin: "Administrador",
  organizador: "Organizador",
  user: "Usuario",
  externo: "Usuario Externo",
};

const COPY = {
  cuenta_nueva: {
    asunto: "Credenciales de acceso — RegisPro",
    preheader:
      "Su usuario y contraseña temporal para ingresar a RegisPro. Cámbiela en el primer acceso.",
    epigrafe: "Credenciales de acceso",
    titulo: "Su cuenta en RegisPro ha sido habilitada",
    intro:
      "Se ha creado su cuenta de acceso a RegisPro, la aplicación de registro y " +
      "acreditación de Transworld. A continuación encontrará sus credenciales y " +
      "las indicaciones para el primer ingreso.",
    pasosTitulo: "Primer ingreso",
    piePorque: "porque se habilitó una cuenta de acceso a su nombre",
  },
  password_restablecida: {
    asunto: "Nueva contraseña de acceso — RegisPro",
    preheader:
      "Nueva contraseña temporal para ingresar a RegisPro. Cámbiela después de entrar.",
    epigrafe: "Contraseña restablecida",
    titulo: "Se restableció la contraseña de su cuenta",
    intro:
      "Se generó una nueva contraseña temporal para su cuenta de RegisPro. " +
      "Utilícela para ingresar y reemplácela por una contraseña propia apenas " +
      "acceda.",
    pasosTitulo: "Cómo continuar",
    piePorque: "porque se restableció la contraseña de su cuenta",
  },
} as const;

/**
 * Espejo de `validarContrasenaFuerte` / `kPasswordHelperText`.
 * Solo cuentan los símbolos `! # % $`; el resto no pasa la validación.
 */
const REQUISITOS = [
  `Mínimo ${LARGO_MINIMO_PASSWORD} caracteres.`,
  "Debe incluir una mayúscula.",
  "Debe incluir una minúscula.",
  "Debe incluir un número.",
  "Debe incluir un símbolo (! # % $).",
];

/** Los pasos admiten HTML en línea (solo `<strong>`). */
const PASOS = [
  "Abra el panel web o la aplicación instalada (Windows, Android o iOS) e ingrese " +
  "el usuario y la contraseña temporal indicados arriba.",
  'Reemplace la contraseña temporal por una propia en <strong style="color:#12203a;">Mi Perfil → Mis Datos de Usuario</strong>.',
  'Verifique su perfil y los eventos asignados en la sección <strong style="color:#12203a;">Inicio</strong> de la aplicación.',
];

export function asuntoCredenciales(motivo: MotivoCredenciales): string {
  return COPY[motivo].asunto;
}

export function etiquetaRol(rol: string | null | undefined): string | null {
  const clave = (rol ?? "").trim();
  if (!clave) return null;
  return ETIQUETAS_ROL[clave] ?? null;
}

export function htmlCredenciales(datos: DatosCredenciales): string {
  const copy = COPY[datos.motivo ?? "cuenta_nueva"];
  const nombre = escapeHtml(datos.nombre);
  const email = escapeHtml(datos.email);
  const password = escapeHtml(datos.password);
  const rol = etiquetaRol(datos.rol);
  const urlAndroid = urlDescargaAndroid(datos.versionApp);

  const filaRol = rol
    ? `
          <tr>
            <td style="padding:14px 20px 20px 20px;">
              <p style="margin:0 0 10px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.2px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">Perfil asignado</p>
              <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
                <td bgcolor="#01386d" style="background-color:#01386d; border-radius:12px; padding:7px 14px 6px 14px; font-family:Arial, Helvetica, sans-serif; font-size:12px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1px; font-weight:bold; color:#ffffff; text-transform:uppercase;">${
      escapeHtml(rol)
    }</td>
              </tr></table>
            </td>
          </tr>`
    : "";

  const pasos = PASOS.map((paso, i) => filaPaso(i + 1, paso)).join(
    '\n          <tr><td colspan="2" height="14" style="height:14px; line-height:14px; font-size:14px;">&nbsp;</td></tr>\n',
  );

  const requisitos = REQUISITOS.map(filaRequisito).join(
    '\n                <tr><td colspan="2" height="8" style="height:8px; line-height:8px; font-size:8px;">&nbsp;</td></tr>\n',
  );

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>${escapeHtml(copy.asunto)}</title>
<!--[if mso]>
<xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml>
<![endif]-->
<style>
  body { margin:0; padding:0; width:100% !important; }
  img { border:0; outline:none; text-decoration:none; }
  table { border-collapse:collapse; }
  a { color:#01386d; }
  @media only screen and (max-width:620px) {
    .wrap { width:100% !important; }
    .pad { padding-left:20px !important; padding-right:20px !important; }
    .h1 { font-size:25px !important; line-height:31px !important; }
    .cred-val { font-size:16px !important; }
  }
</style>
</head>
<body style="margin:0; padding:0; background-color:#eef1f5;">

<!-- Preheader -->
<span style="display:none !important; visibility:hidden; opacity:0; color:transparent; height:0; width:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px;">${
    escapeHtml(copy.preheader)
  }</span>

<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color:#eef1f5;">
<tr>
<td align="center" style="padding:32px 12px 40px 12px;">

  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" class="wrap" style="width:600px; max-width:600px; background-color:#ffffff; border:1px solid #e3e7ed; border-radius:12px; overflow:hidden; box-shadow:0 4px 16px rgba(18,32,58,0.07);">

    <!-- Cabecera -->
    <tr>
      <td width="600" style="width:600px; background-color:#01386d; border-radius:12px 12px 0 0; padding:26px 32px 24px 32px;" class="pad">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
        <tr>
          <td width="330" align="left" valign="middle" style="width:330px; font-family:Arial, Helvetica, sans-serif; font-size:21px; line-height:24px; mso-line-height-rule:exactly; letter-spacing:-0.3px; font-weight:bold; color:#ffffff;">
            Transworld P&amp;T
          </td>
          <td width="206" align="right" valign="middle" style="width:206px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin-left:auto;"><tr>
              <td bgcolor="#12508c" style="background-color:#12508c; border-radius:12px; padding:7px 14px 6px 14px; font-family:Arial, Helvetica, sans-serif; font-size:10px; line-height:13px; mso-line-height-rule:exactly; letter-spacing:1.2px; font-weight:bold; color:#c9e6a0; text-transform:uppercase; white-space:nowrap;">Aplicación RegisPro</td>
            </tr></table>
          </td>
        </tr>
        </table>
      </td>
    </tr>
    <tr><td width="600" height="4" style="width:600px; height:4px; line-height:4px; font-size:4px; background-color:#90c52f;">&nbsp;</td></tr>

    <!-- Título -->
    <tr>
      <td width="600" style="width:600px; padding:36px 32px 0 32px;" class="pad">
        <p style="margin:0 0 12px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.6px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">${
    escapeHtml(copy.epigrafe)
  }</p>
        <h1 class="h1" style="margin:0 0 8px 0; font-family:Arial, Helvetica, sans-serif; font-size:28px; line-height:34px; mso-line-height-rule:exactly; letter-spacing:-0.6px; font-weight:bold; color:#12203a;">${
    escapeHtml(copy.titulo)
  }</h1>
      </td>
    </tr>
    <tr>
      <td width="600" style="width:600px; padding:18px 32px 0 32px;" class="pad">
        <p style="margin:0 0 12px 0; font-family:Arial, Helvetica, sans-serif; font-size:15px; line-height:24px; mso-line-height-rule:exactly; color:#475463;">Estimado/a <strong style="color:#12203a;">${nombre}</strong>:</p>
        <p style="margin:0 0 8px 0; font-family:Arial, Helvetica, sans-serif; font-size:15px; line-height:24px; mso-line-height-rule:exactly; color:#475463;">${
    escapeHtml(copy.intro)
  }</p>
      </td>
    </tr>

    <!-- Credenciales -->
    <tr>
      <td width="600" style="width:600px; padding:26px 32px 0 32px;" class="pad">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color:#f7f8fa; border:1px solid #e3e7ed; border-radius:12px;">
          <tr>
            <td style="padding:14px 20px 13px 20px; background-color:#12203a; border-radius:12px 12px 0 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.4px; font-weight:bold; color:#ffffff; text-transform:uppercase;">
              Datos de ingreso
            </td>
          </tr>
          <tr>
            <td style="padding:20px 20px 10px 20px;">
              <p style="margin:0 0 8px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.2px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">Usuario</p>
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
                <td class="cred-val" style="background-color:#ffffff; border:1px solid #e3e7ed; border-radius:12px; padding:12px 16px; font-family:'Courier New', Courier, monospace; font-size:17px; line-height:22px; mso-line-height-rule:exactly; font-weight:bold; color:#12203a;">${email}</td>
              </tr></table>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 20px ${rol ? "10px" : "20px"} 20px;">
              <p style="margin:0 0 8px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.2px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">Contraseña temporal</p>
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
                <td class="cred-val" style="background-color:#ffffff; border:1px solid #e3e7ed; border-radius:12px; padding:12px 16px; font-family:'Courier New', Courier, monospace; font-size:17px; line-height:22px; mso-line-height-rule:exactly; font-weight:bold; color:#12203a; letter-spacing:1px;">${password}</td>
              </tr></table>
            </td>
          </tr>${filaRol}
        </table>
      </td>
    </tr>

    <!-- Acción principal -->
    <tr>
      <td width="600" style="width:600px; padding:28px 32px 0 32px;" class="pad">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
          <tr>
            <td align="center" style="background-color:#f7f8fa; border:1px solid #e3e7ed; border-radius:12px; padding:16px 26px 15px 26px;">
              <a href="${urlAndroid}" style="display:block; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:18px; mso-line-height-rule:exactly; letter-spacing:0.4px; font-weight:bold; color:#12203a; text-decoration:none; text-transform:uppercase; border-radius:12px;">Descargar para Android</a>
            </td>
          </tr>
        </table>
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
          <tr><td height="12" style="height:12px; line-height:12px; font-size:12px;">&nbsp;</td></tr>
          <tr>
            <td bgcolor="#01386d" style="background-color:#01386d; border-radius:12px; padding:16px 26px 15px 26px; text-align:center;">
              <a href="${URL_PANEL}" style="display:block; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:18px; mso-line-height-rule:exactly; letter-spacing:0.4px; font-weight:bold; color:#ffffff; text-decoration:none; text-transform:uppercase; border-radius:12px;">Iniciar sesión en el panel web</a>
            </td>
          </tr>
        </table>
        <p style="margin:16px 0 0 0; font-family:Arial, Helvetica, sans-serif; font-size:13px; line-height:20px; mso-line-height-rule:exactly; color:#7c8794;">Si usa un iPhone o iPad, el instructivo de instalación va adjunto a este correo.</p>
      </td>
    </tr>

    <!-- Pasos -->
    <tr>
      <td width="600" style="width:600px; padding:36px 32px 0 32px;" class="pad">
        <p style="margin:0 0 20px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.6px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">${
    escapeHtml(copy.pasosTitulo)
  }</p>

        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
${pasos}
        </table>
      </td>
    </tr>

    <!-- Requisitos de contraseña -->
    <tr>
      <td width="600" style="width:600px; padding:34px 32px 0 32px;" class="pad">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color:#f7f8fa; border:1px solid #e3e7ed; border-radius:12px;">
          <tr>
            <td style="padding:20px 20px 20px 20px;">
              <p style="margin:0 0 14px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.4px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">Requisitos de la nueva contraseña</p>
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
${requisitos}
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>

    <!-- Aviso de seguridad -->
    <tr>
      <td width="600" style="width:600px; padding:24px 32px 0 32px;" class="pad">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color:#01386d; border-radius:12px;">
          <tr>
            <td style="padding:22px 22px 22px 22px;">
              <p style="margin:0 0 10px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.4px; font-weight:bold; color:#90c52f; text-transform:uppercase;">Aviso de seguridad</p>
              <p style="margin:0 0 10px 0; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:22px; mso-line-height-rule:exactly; color:#e8edf3;">Estas credenciales son personales e intransferibles. No las comparta por mensajería, ni las reenvíe por correo electrónico.</p>
              <p style="margin:0; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:22px; mso-line-height-rule:exactly; color:#e8edf3;">Transworld nunca le solicitará su contraseña por teléfono ni por correo. Si no solicitó este acceso, informe de inmediato a soporte y no utilice los datos anteriores.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>

    <!-- Soporte -->
    <tr>
      <td width="600" style="width:600px; padding:32px 32px 32px 32px;" class="pad">
        <p style="margin:0 0 14px 0; font-family:Arial, Helvetica, sans-serif; font-size:11px; line-height:14px; mso-line-height-rule:exactly; letter-spacing:1.6px; font-weight:bold; color:#8a95a3; text-transform:uppercase;">Soporte</p>
        <p style="margin:0; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:22px; mso-line-height-rule:exactly; color:#475463;">Escriba a <a href="mailto:${SOPORTE_EMAIL}" style="color:#01386d; text-decoration:underline; font-weight:bold;">${SOPORTE_EMAIL}</a> si no reconoce este correo o necesita ayuda para ingresar.</p>
      </td>
    </tr>

    <!-- Pie -->
    <tr>
      <td width="600" style="width:600px; background-color:#f7f8fa; border-radius:0 0 12px 12px; border-top:1px solid #e3e7ed; padding:22px 32px 26px 32px;" class="pad">
        <p style="margin:0 0 10px 0; font-family:Arial, Helvetica, sans-serif; font-size:12px; line-height:19px; mso-line-height-rule:exactly; color:#8a95a3;">Correo enviado automáticamente por <strong style="color:#12203a;">RegisPro</strong> a ${email} ${
    escapeHtml(copy.piePorque)
  }.</p>
        <p style="margin:0; font-family:Arial, Helvetica, sans-serif; font-size:12px; line-height:19px; mso-line-height-rule:exactly; color:#8a95a3;">Transworld P&amp;T · Santiago, Chile</p>
      </td>
    </tr>

  </table>

</td>
</tr>
</table>
</body>
</html>`;
}

/** Alternativa en texto plano; mismo contenido, sin decoración. */
export function textoCredenciales(datos: DatosCredenciales): string {
  const copy = COPY[datos.motivo ?? "cuenta_nueva"];
  const rol = etiquetaRol(datos.rol);
  const urlAndroid = urlDescargaAndroid(datos.versionApp);

  const lineas = [
    copy.titulo.toUpperCase(),
    "",
    `Estimado/a ${datos.nombre}:`,
    "",
    copy.intro,
    "",
    "DATOS DE INGRESO",
    `Usuario: ${datos.email}`,
    `Contraseña temporal: ${datos.password}`,
  ];
  if (rol) lineas.push(`Perfil asignado: ${rol}`);

  lineas.push(
    "",
    `Descargar para Android: ${urlAndroid}`,
    `Panel web: ${URL_PANEL}`,
    "Si usa un iPhone o iPad, el instructivo de instalación va adjunto a este correo.",
    "También puede ingresar con los mismos datos desde la aplicación RegisPro",
    "instalada en su equipo o teléfono.",
    "",
    copy.pasosTitulo.toUpperCase(),
    ...PASOS.map((paso, i) => `${i + 1}. ${sinEtiquetas(paso)}`),
    "",
    "REQUISITOS DE LA NUEVA CONTRASEÑA",
    ...REQUISITOS.map((r) => `- ${r}`),
    "",
    "AVISO DE SEGURIDAD",
    "Estas credenciales son personales e intransferibles. No las comparta por",
    "mensajería, ni las reenvíe por correo electrónico. Transworld nunca le",
    "solicitará su contraseña por teléfono ni por correo. Si no solicitó este",
    "acceso, informe de inmediato a soporte y no utilice los datos anteriores.",
    "",
    `Soporte: ${SOPORTE_EMAIL}`,
    "",
    `Correo enviado automáticamente por RegisPro a ${datos.email} ${copy.piePorque}.`,
    "Transworld P&T · Santiago, Chile",
  );

  return lineas.join("\n");
}

function filaPaso(numero: number, textoHtml: string): string {
  return `          <tr>
            <td width="40" valign="top">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
                <td width="32" height="32" align="center" valign="middle" bgcolor="#eef2f7" style="width:32px; height:32px; background-color:#eef2f7; border-radius:12px; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:32px; mso-line-height-rule:exactly; font-weight:bold; color:#01386d; text-align:center;">${numero}</td>
              </tr></table>
            </td>
            <td valign="middle" style="padding-left:14px; font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:22px; mso-line-height-rule:exactly; color:#475463;">${textoHtml}</td>
          </tr>`;
}

function filaRequisito(texto: string): string {
  return `                <tr>
                  <td width="22" valign="top" style="padding-top:1px;"><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td width="16" height="16" align="center" valign="middle" bgcolor="#90c52f" style="width:16px; height:16px; background-color:#90c52f; border-radius:12px; font-family:Arial, Helvetica, sans-serif; font-size:10px; line-height:16px; mso-line-height-rule:exactly; font-weight:bold; color:#12203a; text-align:center;">&#10003;</td></tr></table></td>
                  <td valign="top" style="font-family:Arial, Helvetica, sans-serif; font-size:14px; line-height:22px; mso-line-height-rule:exactly; color:#475463;">${
    escapeHtml(texto)
  }</td>
                </tr>`;
}

function sinEtiquetas(html: string): string {
  return html.replace(/<[^>]+>/g, "").replaceAll("&amp;", "&");
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
