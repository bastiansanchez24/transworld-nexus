import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

/**
 * Cliente admin con service role.
 * En Edge Functions el runtime reenvía el Authorization del request original;
 * hay que forzar Bearer del service role o Auth Admin usa el JWT del usuario
 * (ES256) y falla con "unrecognized JWT kid <nil>".
 */
export function createAdminClient(
  supabaseUrl: string,
  serviceRoleKey: string,
): SupabaseClient {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  });
}
