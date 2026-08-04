-- Eliminación personal de notificaciones (ocultar por usuario).
-- Idempotente: seguro de re-ejecutar.

CREATE TABLE IF NOT EXISTS public.notificaciones_ocultas (
  usuario_id       uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  notificacion_id  uuid NOT NULL REFERENCES public.notificaciones (id) ON DELETE CASCADE,
  oculta_at        timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (usuario_id, notificacion_id)
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_ocultas_usuario_id
  ON public.notificaciones_ocultas (usuario_id);

CREATE OR REPLACE FUNCTION public.rpe_ocultar_todas_notificaciones()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;

  INSERT INTO public.notificaciones_ocultas (usuario_id, notificacion_id)
  SELECT v_user_id, n.id
  FROM public.notificaciones n
  ON CONFLICT (usuario_id, notificacion_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpe_ocultar_todas_notificaciones() TO authenticated;

ALTER TABLE public.notificaciones_ocultas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rpe_notificaciones_ocultas_select ON public.notificaciones_ocultas;
CREATE POLICY rpe_notificaciones_ocultas_select ON public.notificaciones_ocultas
  FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_notificaciones_ocultas_insert ON public.notificaciones_ocultas;
CREATE POLICY rpe_notificaciones_ocultas_insert ON public.notificaciones_ocultas
  FOR INSERT TO authenticated
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_notificaciones_ocultas_delete ON public.notificaciones_ocultas;
CREATE POLICY rpe_notificaciones_ocultas_delete ON public.notificaciones_ocultas
  FOR DELETE TO authenticated
  USING (usuario_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON public.notificaciones_ocultas TO authenticated;
