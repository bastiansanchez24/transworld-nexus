/** Espejo de `password_policy.dart` / `password_generator.dart` en Flutter. */
const MAYUSCULAS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const MINUSCULAS = "abcdefghijkmnopqrstuvwxyz";
const NUMEROS = "23456789";
const SIMBOLOS = "!#%$";
const GRUPOS = [MAYUSCULAS, MINUSCULAS, NUMEROS, SIMBOLOS];
const TODOS = GRUPOS.join("");

/** Alineado con Auth: minimum_password_length = 8. */
export const LARGO_MINIMO_PASSWORD = 8;

/** Entero aleatorio en [0, max) sin sesgo modular (rejection sampling). */
function randomInt(max: number): number {
  const limite = Math.floor(256 / max) * max;
  const byte = new Uint8Array(1);
  while (true) {
    crypto.getRandomValues(byte);
    if (byte[0]! < limite) return byte[0]! % max;
  }
}

function elegir(pool: string): string {
  return pool[randomInt(pool.length)]!;
}

export function generarContrasena(length = LARGO_MINIMO_PASSWORD): string {
  const largo = Math.max(length, GRUPOS.length);
  const chars: string[] = GRUPOS.map(elegir);
  for (let i = GRUPOS.length; i < largo; i++) {
    chars.push(elegir(TODOS));
  }

  // Sin barajar, los primeros caracteres seguirían siempre el orden de grupo.
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j]!, chars[i]!];
  }

  return chars.join("");
}

/** Misma regla que `validarContrasenaFuerte` en Flutter / Auth de Supabase. */
export function esContrasenaFuerte(password: string): boolean {
  return password.length >= LARGO_MINIMO_PASSWORD &&
    /[A-Z]/.test(password) &&
    /[a-z]/.test(password) &&
    /[0-9]/.test(password) &&
    /[!#%$]/.test(password);
}
