/**
 * Tipos mínimos de Deno para el language service de TypeScript.
 * Las Edge Functions corren en Deno; este repo no usa el Deno LSP.
 */
declare namespace Deno {
  interface Env {
    get(key: string): string | undefined;
  }

  const env: Env;

  function serve(
    handler: (request: Request) => Response | Promise<Response>,
  ): void;
}
