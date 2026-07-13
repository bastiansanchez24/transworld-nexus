-- ============================================================
-- MIGRACIÓN (opcional): columnas extra en public.registrados
-- ============================================================
--
-- La BD de producción puede no tener estas columnas. La app Flutter
-- funciona sin ellas; este script las agrega si quieres trazabilidad
-- de origen (app / excel / público) y timestamp de acreditación.
--
-- Cómo aplicar: Supabase Dashboard → SQL Editor → ejecutar completo.
-- ============================================================

BEGIN;

ALTER TABLE public.registrados
  ADD COLUMN IF NOT EXISTS origen text NOT NULL DEFAULT 'app';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'registrados_origen_check'
  ) THEN
    ALTER TABLE public.registrados
      ADD CONSTRAINT registrados_origen_check
      CHECK (origen = ANY (ARRAY['app', 'excel', 'publico']));
  END IF;
END $$;

ALTER TABLE public.registrados
  ADD COLUMN IF NOT EXISTS acreditado_en timestamptz;

ALTER TABLE public.registrados
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT timezone('utc', now());

COMMIT;
