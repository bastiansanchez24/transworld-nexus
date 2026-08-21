-- Eventos y actividades de captura admiten únicamente Chile o Perú.
-- La app preselecciona Chile; el default cubre además inserciones directas.

ALTER TABLE public.eventos
  ALTER COLUMN pais SET DEFAULT 'Chile',
  ALTER COLUMN pais SET NOT NULL;

ALTER TABLE public.eventos
  DROP CONSTRAINT IF EXISTS eventos_pais_check;
ALTER TABLE public.eventos
  ADD CONSTRAINT eventos_pais_check CHECK (pais IN ('Chile', 'Perú'));

ALTER TABLE public.eventos_leads
  ALTER COLUMN pais SET DEFAULT 'Chile',
  ALTER COLUMN pais SET NOT NULL;

ALTER TABLE public.eventos_leads
  DROP CONSTRAINT IF EXISTS eventos_leads_pais_check;
ALTER TABLE public.eventos_leads
  ADD CONSTRAINT eventos_leads_pais_check CHECK (pais IN ('Chile', 'Perú'));
