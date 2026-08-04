-- Fijados personales por usuario para eventos y campañas (leads).
-- Ejecutar en el SQL Editor de Supabase (o aplicar sobre schema.sql).

-- ----------------------------------------------------------------
-- 1. Tablas
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios_eventos_fijados (
  usuario_id  uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  evento_id   uuid NOT NULL REFERENCES public.eventos (id) ON DELETE CASCADE,
  fijado_en   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (usuario_id, evento_id)
);

CREATE TABLE IF NOT EXISTS public.usuarios_eventos_leads_fijados (
  usuario_id      uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  evento_lead_id  uuid NOT NULL REFERENCES public.eventos_leads (id) ON DELETE CASCADE,
  fijado_en       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (usuario_id, evento_lead_id)
);

CREATE INDEX IF NOT EXISTS idx_usuarios_eventos_fijados_usuario
  ON public.usuarios_eventos_fijados (usuario_id);

CREATE INDEX IF NOT EXISTS idx_usuarios_eventos_leads_fijados_usuario
  ON public.usuarios_eventos_leads_fijados (usuario_id);

-- ----------------------------------------------------------------
-- 2. RLS
-- ----------------------------------------------------------------
ALTER TABLE public.usuarios_eventos_fijados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_eventos_leads_fijados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rpe_usuarios_eventos_fijados_select ON public.usuarios_eventos_fijados;
CREATE POLICY rpe_usuarios_eventos_fijados_select ON public.usuarios_eventos_fijados
  FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_usuarios_eventos_fijados_insert ON public.usuarios_eventos_fijados;
CREATE POLICY rpe_usuarios_eventos_fijados_insert ON public.usuarios_eventos_fijados
  FOR INSERT TO authenticated
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_usuarios_eventos_fijados_delete ON public.usuarios_eventos_fijados;
CREATE POLICY rpe_usuarios_eventos_fijados_delete ON public.usuarios_eventos_fijados
  FOR DELETE TO authenticated
  USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_usuarios_eventos_leads_fijados_select ON public.usuarios_eventos_leads_fijados;
CREATE POLICY rpe_usuarios_eventos_leads_fijados_select ON public.usuarios_eventos_leads_fijados
  FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_usuarios_eventos_leads_fijados_insert ON public.usuarios_eventos_leads_fijados;
CREATE POLICY rpe_usuarios_eventos_leads_fijados_insert ON public.usuarios_eventos_leads_fijados
  FOR INSERT TO authenticated
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_usuarios_eventos_leads_fijados_delete ON public.usuarios_eventos_leads_fijados;
CREATE POLICY rpe_usuarios_eventos_leads_fijados_delete ON public.usuarios_eventos_leads_fijados
  FOR DELETE TO authenticated
  USING (usuario_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON public.usuarios_eventos_fijados TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.usuarios_eventos_leads_fijados TO authenticated;
