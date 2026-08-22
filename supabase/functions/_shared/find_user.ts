/**
 * Forma mínima del usuario de Auth que consumen las funciones.
 * No se tipa contra `User` de supabase-js para no acoplar `_shared` a la
 * versión del cliente que importe cada función.
 */
export interface AuthUserLite {
  id: string;
  email?: string | null;
  user_metadata?: Record<string, unknown> | null;
}

/** Respuesta de PostgREST: `{ data, error }`, ambos de tipo desconocido acá. */
type RespuestaRpc = PromiseLike<{ data: unknown; error: unknown }>;

interface AdminClientRpc {
  rpc: (fn: string, args: Record<string, unknown>) => RespuestaRpc;
}

interface AdminClientAuth extends AdminClientRpc {
  auth: {
    admin: {
      getUserById: (
        id: string,
      ) => Promise<
        { data: { user: AuthUserLite | null } | null; error: unknown }
      >;
    };
  };
}

/**
 * Resuelve usuario Auth por email sin listUsers:
 * RPC → id, luego admin.getUserById.
 */
export async function findAuthUserByEmail(
  adminClient: AdminClientAuth,
  email: string,
): Promise<AuthUserLite | null> {
  const { data: userId, error } = await adminClient.rpc(
    "rpe_auth_user_id_por_email",
    { email_input: email.trim().toLowerCase() },
  );
  if (error) throw error;
  if (!userId) return null;

  const { data, error: userError } = await adminClient.auth.admin.getUserById(
    userId as string,
  );
  if (userError) throw userError;
  return data?.user ?? null;
}
