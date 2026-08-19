-- Actividad de captura interna: hereda ficha e imagen del evento ligado.
-- Idempotente: también vive en supabase/schema.sql.

ALTER TABLE public.eventos_leads
  ADD COLUMN IF NOT EXISTS imagen_url text;

UPDATE public.eventos_leads el
SET
  nombre = e.nombre,
  fecha = e.fecha,
  pais = e.pais,
  tematica = e.tematica,
  certificacion_capacitacion = e.certificacion_capacitacion,
  imagen_url = e.imagen_url
FROM public.eventos e
WHERE el.tipo_evento_lead = 'interno'
  AND el.evento_origen_id = e.id;

CREATE OR REPLACE FUNCTION public.rpe_sync_actividad_interna_desde_evento()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.eventos_leads
  SET
    nombre = NEW.nombre,
    fecha = NEW.fecha,
    pais = NEW.pais,
    tematica = NEW.tematica,
    certificacion_capacitacion = NEW.certificacion_capacitacion,
    imagen_url = NEW.imagen_url
  WHERE evento_origen_id = NEW.id
    AND tipo_evento_lead = 'interno';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_eventos_sync_actividad_interna ON public.eventos;
CREATE TRIGGER trg_eventos_sync_actividad_interna
  AFTER UPDATE OF nombre, fecha, pais, tematica,
    certificacion_capacitacion, imagen_url
  ON public.eventos
  FOR EACH ROW
  EXECUTE FUNCTION public.rpe_sync_actividad_interna_desde_evento();

CREATE OR REPLACE FUNCTION public.rpe_lock_actividad_interna_campos()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  coincide boolean;
BEGIN
  IF NEW.tipo_evento_lead IS DISTINCT FROM OLD.tipo_evento_lead
     OR NEW.evento_origen_id IS DISTINCT FROM OLD.evento_origen_id THEN
    RAISE EXCEPTION
      'No se puede cambiar el origen de una actividad de captura';
  END IF;

  IF NEW.tipo_evento_lead <> 'interno' THEN
    RETURN NEW;
  END IF;

  IF NEW.nombre IS NOT DISTINCT FROM OLD.nombre
     AND NEW.fecha IS NOT DISTINCT FROM OLD.fecha
     AND NEW.pais IS NOT DISTINCT FROM OLD.pais
     AND NEW.tematica IS NOT DISTINCT FROM OLD.tematica
     AND NEW.certificacion_capacitacion
           IS NOT DISTINCT FROM OLD.certificacion_capacitacion
     AND NEW.imagen_url IS NOT DISTINCT FROM OLD.imagen_url THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.eventos e
    WHERE e.id = NEW.evento_origen_id
      AND e.nombre IS NOT DISTINCT FROM NEW.nombre
      AND e.fecha IS NOT DISTINCT FROM NEW.fecha
      AND e.pais IS NOT DISTINCT FROM NEW.pais
      AND e.tematica IS NOT DISTINCT FROM NEW.tematica
      AND e.certificacion_capacitacion
            IS NOT DISTINCT FROM NEW.certificacion_capacitacion
      AND e.imagen_url IS NOT DISTINCT FROM NEW.imagen_url
  ) INTO coincide;

  IF NOT coincide THEN
    RAISE EXCEPTION
      'Los datos de una actividad de captura interna se heredan del evento ligado';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_eventos_leads_lock_interna ON public.eventos_leads;
CREATE TRIGGER trg_eventos_leads_lock_interna
  BEFORE UPDATE ON public.eventos_leads
  FOR EACH ROW
  EXECUTE FUNCTION public.rpe_lock_actividad_interna_campos();
