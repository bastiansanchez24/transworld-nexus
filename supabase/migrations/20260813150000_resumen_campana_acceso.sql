-- El resumen de una campaña lo ve todo el que puede abrirla, no solo los
-- roles internos: el externo autorizado por evento homónimo también entra al
-- hub y veía las tarjetas en 0. Sigue sin exponer filas: solo dos conteos.

BEGIN;

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

REVOKE ALL ON FUNCTION public.cl_resumen_campana(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cl_resumen_campana(uuid) TO authenticated;

COMMIT;
