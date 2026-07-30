-- ============================================================
-- FIX: ambigüedad de usuario_id en rpe_actualizar_rol_usuario
-- ============================================================
--
-- Causa: el parámetro `usuario_id` colisiona con la columna homónima en
-- usuarios_eventos. En PL/pgSQL no se puede calificar con
-- `nombre_funcion.parametro`; hay que copiar el valor a una variable local.
--
-- Cómo aplicar:
--   Supabase Dashboard → SQL Editor → pegar y ejecutar este script
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpe_actualizar_rol_usuario(usuario_id uuid, nuevo_rol text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario_id uuid := usuario_id;
BEGIN
  IF NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede cambiar roles';
  END IF;

  IF nuevo_rol NOT IN ('admin', 'organizador', 'user') THEN
    RAISE EXCEPTION 'Rol inválido: %', nuevo_rol;
  END IF;

  DELETE FROM public.usuarios_eventos ue
  WHERE ue.usuario_id = v_usuario_id;

  UPDATE public.perfiles p
  SET rol = nuevo_rol,
      evento_asignado_id = NULL
  WHERE p.id = v_usuario_id;
END;
$$;
