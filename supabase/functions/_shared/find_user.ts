/** Comprueba email vía RPC (evita auth.admin.listUsers, que falla con "Database error finding users"). */
export async function emailYaRegistrado(
  // deno-lint-ignore no-explicit-any
  adminClient: { rpc: (fn: string, args: Record<string, unknown>) => Promise<any> },
  email: string,
): Promise<boolean> {
  const { data, error } = await adminClient.rpc("verificar_usuario_registrado", {
    email_check: email.trim().toLowerCase(),
  });
  if (error) throw error;
  return data === true;
}

/**
 * Resuelve usuario Auth por email sin listUsers:
 * RPC → id, luego admin.getUserById.
 */
export async function findAuthUserByEmail(
  // deno-lint-ignore no-explicit-any
  adminClient: {
    rpc: (fn: string, args: Record<string, unknown>) => Promise<any>;
    auth: { admin: { getUserById: (id: string) => Promise<any> } };
  },
  email: string,
) {
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
