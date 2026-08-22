/**
 * Resuelve el `.apk` que el correo de credenciales ofrece descargar.
 *
 * Es la misma fuente que usa el OTA de la app (`GitHubReleaseRepository` /
 * `GitHubRelease.resolveNexusApk` en Dart): la Release más reciente del
 * repositorio. GitHub no publica una URL estable al asset —el nombre lleva la
 * versión dentro—, así que el enlace directo hay que resolverlo en el momento
 * de enviar el correo.
 */

const GITHUB_OWNER = "bsanchezTW";
const GITHUB_REPO = "transworld-nexus";

/** Página de la Release más reciente: respaldo si la API no responde. */
export function urlReleaseMasReciente(): string {
  return `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;
}

interface AssetRelease {
  name: string;
  size: number;
  browser_download_url: string;
}

/** `v1.6.9` → `1.6.9`. Espejo de `stripVersionPrefix` en Dart. */
function sinPrefijoDeVersion(tag: string): string {
  return tag.trim().replace(/^v/i, "");
}

function esApkDeRegisPro(nombre: string): boolean {
  const lower = nombre.toLowerCase();
  return lower.endsWith(".apk") &&
    (lower.startsWith("android-regispro-") ||
      lower.startsWith("android-nexus-"));
}

/**
 * Mismo contrato que `GitHubRelease.resolveNexusApk`:
 * 1. Solo assets `android-regispro-*.apk` (o el legacy `android-nexus-*`).
 * 2. Preferir el que coincide con el tag.
 * 3. Si hay varios, el de mayor tamaño.
 */
export function elegirApk(
  tagName: string,
  assets: AssetRelease[],
): AssetRelease | null {
  const candidatos = assets.filter((a) => esApkDeRegisPro(a.name ?? ""));
  if (candidatos.length === 0) return null;

  const tag = sinPrefijoDeVersion(tagName ?? "");
  for (
    const preferido of [
      `android-regispro-v${tag}.apk`,
      `android-nexus-v${tag}.apk`,
    ]
  ) {
    const exacto = candidatos.find((a) => a.name.toLowerCase() === preferido);
    if (exacto) return exacto;
  }

  return [...candidatos].sort((a, b) => (b.size ?? 0) - (a.size ?? 0))[0];
}

/**
 * URL directa al `.apk` de la última Release, o `null` si no se pudo resolver.
 *
 * Nunca lanza ni se cuelga: el correo con las credenciales importa más que el
 * botón de descarga, así que ante cualquier fallo se devuelve `null` y quien
 * llama cae a [urlReleaseMasReciente].
 */
export async function resolverUrlApkAndroid(
  { timeoutMs = 6000 }: { timeoutMs?: number } = {},
): Promise<string | null> {
  try {
    const res = await fetch(
      `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`,
      {
        headers: {
          "Accept": "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
          "User-Agent": "RegisPro-Correo",
        },
        signal: AbortSignal.timeout(timeoutMs),
      },
    );
    if (!res.ok) return null;

    const release = await res.json() as {
      tag_name?: string;
      assets?: AssetRelease[];
    };
    const apk = elegirApk(release.tag_name ?? "", release.assets ?? []);
    const url = apk?.browser_download_url;
    return url && url.length > 0 ? url : null;
  } catch (error) {
    console.error("No se pudo resolver el APK de la última Release", error);
    return null;
  }
}
