-- El resumen de campaña lo puede pedir quien abre la actividad, incluido el
-- externo autorizado. Tras consolidar schema.sql, producción podía quedarse
-- con cl_resumen_campana solo-internos (20260813140000) y el snapshot del
-- externo fallaba en "Asistentes y leads" con 42501.
-- Idempotente: también vive en supabase/schema.sql.

CREATE OR REPLACE FUNCTION public.cl_externo_campana_autorizada(p_campana_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.eventos_leads el
    WHERE el.id = p_campana_id
      AND (
        public.cl_externo_evento_origen_autorizado(el.evento_origen_id)
        OR (
          el.evento_origen_id IS NULL
          AND public.cl_externo_nombre_campana_autorizado(el.nombre)
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.cl_resumen_campana(p_evento_id uuid)
RETURNS TABLE (total bigint, empresas bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF p_evento_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Campaña inválida';
  END IF;

  IF NOT (
    public.rpe_is_internal_user()
    OR public.cl_externo_campana_autorizada(p_evento_id)
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Sin acceso al resumen de la campaña';
  END IF;

  RETURN QUERY
  SELECT
    count(*)::bigint AS total,
    count(*) FILTER (
      WHERE nullif(btrim(l.empresa), '') IS NOT NULL
    )::bigint AS empresas
  FROM public.leads l
  WHERE l.evento_id = p_evento_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cl_externo_campana_autorizada(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cl_externo_campana_autorizada(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.cl_externo_nombre_campana_autorizado(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cl_externo_nombre_campana_autorizado(text) TO authenticated;
REVOKE ALL ON FUNCTION public.cl_resumen_campana(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cl_resumen_campana(uuid) TO authenticated;
