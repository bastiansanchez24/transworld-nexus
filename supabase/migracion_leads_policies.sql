-- ============================================================
-- MIGRACIÓN: políticas RLS + GRANTs para leads / eventos_leads
-- ============================================================
--
-- Síntoma en la app: hay filas en public.eventos_leads y public.leads
-- (visibles en el SQL Editor del dashboard), pero el módulo Capturador
-- muestra listas vacías o errores al cargar.
--
-- Causa habitual: las tablas existen con RLS habilitado pero sin
-- políticas cl_* ni GRANT para el rol authenticated.
--
-- Cómo aplicar:
--   1. Supabase Dashboard → SQL Editor
--   2. Pegar y ejecutar este script completo
--   3. Settings → API → Reload schema (o esperar ~1 min)
-- ============================================================

BEGIN;

ALTER TABLE public.eventos_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

-- --- eventos_leads ---
DROP POLICY IF EXISTS cl_eventos_leads_select ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_select ON public.eventos_leads
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS cl_eventos_leads_insert ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_insert ON public.eventos_leads
  FOR INSERT TO authenticated
  WITH CHECK (perfil_id IS NULL OR perfil_id = auth.uid());

DROP POLICY IF EXISTS cl_eventos_leads_update ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_update ON public.eventos_leads
  FOR UPDATE TO authenticated
  USING (perfil_id = auth.uid() OR public.rpe_is_admin())
  WITH CHECK (perfil_id = auth.uid() OR public.rpe_is_admin());

DROP POLICY IF EXISTS cl_eventos_leads_delete ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_delete ON public.eventos_leads
  FOR DELETE TO authenticated
  USING (perfil_id = auth.uid() OR public.rpe_is_admin());

-- --- leads ---
DROP POLICY IF EXISTS cl_leads_select ON public.leads;
CREATE POLICY cl_leads_select ON public.leads
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS cl_leads_insert ON public.leads;
CREATE POLICY cl_leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (perfil_id IS NULL OR perfil_id = auth.uid());

DROP POLICY IF EXISTS cl_leads_update ON public.leads;
CREATE POLICY cl_leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (perfil_id = auth.uid() OR public.rpe_is_admin())
  WITH CHECK (perfil_id = auth.uid() OR public.rpe_is_admin());

DROP POLICY IF EXISTS cl_leads_delete ON public.leads;
CREATE POLICY cl_leads_delete ON public.leads
  FOR DELETE TO authenticated
  USING (public.rpe_is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.eventos_leads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.leads TO authenticated;

COMMIT;
