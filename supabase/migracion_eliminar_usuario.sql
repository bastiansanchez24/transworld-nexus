-- ============================================================
-- MIGRACIÓN: RPC public.rpe_eliminar_usuario
-- + perfil sistema "Usuario eliminado"
-- ============================================================
--
-- Regla de negocio: al eliminar un usuario, las filas de
-- registrados.acreditado_por que lo referencian pasan a apuntar
-- al perfil sistema cuyo nombre_completo es 'Usuario eliminado'
-- (acreditado_por es uuid FK a perfiles, no un campo de texto).
--
-- Cómo aplicar:
--   1. Abrir Supabase Dashboard → SQL Editor
--   2. Pegar y ejecutar este script completo
--
-- Es idempotente.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0. Asegurar columna acreditado_por (puede faltar en bases viejas)
-- ------------------------------------------------------------
ALTER TABLE public.registrados
  ADD COLUMN IF NOT EXISTS acreditado_por uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'registrados_acreditado_por_fkey'
  ) THEN
    ALTER TABLE public.registrados
      ADD CONSTRAINT registrados_acreditado_por_fkey
      FOREIGN KEY (acreditado_por)
      REFERENCES public.perfiles (id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- ------------------------------------------------------------
-- 1. Perfil sistema "Usuario eliminado"
--    UUID fijo: 00000000-0000-0000-0000-000000000001
-- ------------------------------------------------------------
-- perfiles.id referencia auth.users, así que primero el usuario
-- de auth (sin login útil: ban permanente).
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_super_admin,
  is_sso_user,
  is_anonymous,
  banned_until,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  'sistema.usuario.eliminado@internal.local',
  crypt(gen_random_uuid()::text, gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"nombre_completo":"Usuario eliminado"}'::jsonb,
  now(),
  now(),
  false,
  false,
  false,
  'infinity'::timestamptz,
  '',
  '',
  '',
  ''
)
ON CONFLICT (id) DO NOTHING;

-- El trigger rpe_handle_new_user suele crear el perfil al insertar
-- auth.users. No tocamos `activo` en un UPDATE genérico: el trigger
-- rpe_prevent_role_self_escalation lo bloquea fuera de una sesión admin
-- (p.ej. SQL Editor). Desactivamos el trigger solo para este ajuste.
INSERT INTO public.perfiles (id, nombre_completo, rol, activo, cambiar_pass)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Usuario eliminado',
  'user',
  false,
  false
)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.perfiles
  DISABLE TRIGGER trg_perfiles_prevent_role_escalation;

UPDATE public.perfiles
SET
  nombre_completo = 'Usuario eliminado',
  activo = false,
  cambiar_pass = false,
  rol = 'user'
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

ALTER TABLE public.perfiles
  ENABLE TRIGGER trg_perfiles_prevent_role_escalation;

-- ------------------------------------------------------------
-- 2. RPC de eliminación
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpe_eliminar_usuario(uuid);

CREATE FUNCTION public.rpe_eliminar_usuario(usuario_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000001';
BEGIN
  IF usuario_id = v_sentinel THEN
    RAISE EXCEPTION 'No se puede eliminar el perfil sistema';
  END IF;

  IF NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede eliminar usuarios';
  END IF;

  IF usuario_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes eliminar tu propia cuenta';
  END IF;

  -- Acreditaciones: reasignar al perfil "Usuario eliminado".
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'registrados'
      AND column_name = 'acreditado_por'
  ) THEN
    UPDATE public.registrados
    SET acreditado_por = v_sentinel
    WHERE acreditado_por = usuario_id;
  END IF;

  -- Otras referencias históricas: quedan sin autor (NULL).
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'eventos' AND column_name = 'creado_por'
  ) THEN
    UPDATE public.eventos SET creado_por = NULL WHERE creado_por = usuario_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'registrados' AND column_name = 'ingresado_por'
  ) THEN
    UPDATE public.registrados SET ingresado_por = NULL WHERE ingresado_por = usuario_id;
  END IF;

  IF to_regclass('public.usuarios_eventos') IS NOT NULL THEN
    DELETE FROM public.usuarios_eventos ue
      WHERE ue.usuario_id = rpe_eliminar_usuario.usuario_id;
  END IF;

  IF to_regclass('public.eventos_leads') IS NOT NULL THEN
    UPDATE public.eventos_leads SET perfil_id = NULL WHERE perfil_id = usuario_id;
  END IF;
  IF to_regclass('public.leads') IS NOT NULL THEN
    UPDATE public.leads SET perfil_id = NULL WHERE perfil_id = usuario_id;
  END IF;

  DELETE FROM public.perfiles WHERE id = usuario_id;

  BEGIN
    DELETE FROM auth.users WHERE id = usuario_id;
  EXCEPTION WHEN foreign_key_violation THEN
    UPDATE auth.users SET banned_until = 'infinity' WHERE id = usuario_id;
    RETURN 'desactivado';
  END;

  RETURN 'eliminado';
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpe_eliminar_usuario(uuid) TO authenticated;

COMMIT;
