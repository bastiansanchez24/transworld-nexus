/** Misma alfabeto que `generarContrasenaInvitacion` en Flutter. */
const CHARS =
  "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

export function generarContrasena(length = 14): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += CHARS[bytes[i]! % CHARS.length];
  }
  return out;
}
