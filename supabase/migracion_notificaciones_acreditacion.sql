-- Hitos de acreditación: notificaciones al 20%, 50%, 80% y 100%.
-- Ejecutar en el SQL Editor o: supabase db query --linked -f supabase/migracion_notificaciones_acreditacion.sql

-- ----------------------------------------------------------------
-- 1. Ampliar tipos de notificación
-- ----------------------------------------------------------------
ALTER TABLE public.notificaciones
  DROP CONSTRAINT IF EXISTS notificaciones_tipo_check;

ALTER TABLE public.notificaciones
  ADD CONSTRAINT notificaciones_tipo_check
  CHECK (tipo = ANY (ARRAY[
    'registro',
    'acreditacion_20',
    'acreditacion_50',
    'acreditacion_80',
    'acreditacion_100'
  ]));

-- Evita duplicar el mismo hito por evento (p. ej. des-acreditar y volver a acreditar).
CREATE TABLE IF NOT EXISTS public.evento_hitos_acreditacion (
  evento_id   uuid NOT NULL REFERENCES public.eventos (id) ON DELETE CASCADE,
  umbral      int  NOT NULL CHECK (umbral = ANY (ARRAY[20, 50, 80, 100])),
  notificado_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (evento_id, umbral)
);

-- ----------------------------------------------------------------
-- 2. Trigger: al acreditar, evaluar hitos cruzados
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpe_notificar_hitos_acreditacion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total           int;
  v_acreditados     int;
  v_old_acreditados int;
  v_old_pct         int;
  v_new_pct         int;
  v_nombre_evento   text;
  v_umbral          int;
  v_tipo            text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.acreditado IS NOT DISTINCT FROM NEW.acreditado
       OR NEW.acreditado IS NOT TRUE THEN
      RETURN NEW;
    END IF;
  ELSIF TG_OP = 'INSERT' THEN
    IF NEW.acreditado IS NOT TRUE THEN
      RETURN NEW;
    END IF;
  END IF;

  SELECT count(*)::int,
         count(*) FILTER (WHERE acreditado)::int
  INTO v_total, v_acreditados
  FROM public.registrados
  WHERE evento_id = NEW.evento_id;

  IF v_total = 0 THEN
    RETURN NEW;
  END IF;

  v_new_pct := (v_acreditados * 100) / v_total;
  v_old_acreditados := v_acreditados - 1;
  v_old_pct := (v_old_acreditados * 100) / v_total;

  SELECT e.nombre INTO v_nombre_evento
  FROM public.eventos e
  WHERE e.id = NEW.evento_id;

  IF v_nombre_evento IS NULL THEN
    v_nombre_evento := 'Evento';
  END IF;

  FOREACH v_umbral IN ARRAY ARRAY[20, 50, 80, 100] LOOP
    IF v_old_pct < v_umbral AND v_new_pct >= v_umbral THEN
      INSERT INTO public.evento_hitos_acreditacion (evento_id, umbral)
      VALUES (NEW.evento_id, v_umbral)
      ON CONFLICT DO NOTHING;

      IF NOT FOUND THEN
        CONTINUE;
      END IF;

      v_tipo := 'acreditacion_' || v_umbral::text;

      INSERT INTO public.notificaciones (
        tipo,
        titulo,
        cuerpo,
        registrado_id,
        evento_id,
        nombre_registrado,
        nombre_evento
      ) VALUES (
        v_tipo,
        'Hito de acreditación',
        v_nombre_evento || ' alcanzó el ' || v_umbral
          || '% de acreditación (' || v_acreditados || '/' || v_total
          || ' acreditados)',
        NEW.id,
        NEW.evento_id,
        NEW.nombre_completo,
        v_nombre_evento
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_registrados_hitos_acreditacion_insert ON public.registrados;
CREATE TRIGGER trg_registrados_hitos_acreditacion_insert
  AFTER INSERT ON public.registrados
  FOR EACH ROW EXECUTE FUNCTION public.rpe_notificar_hitos_acreditacion();

DROP TRIGGER IF EXISTS trg_registrados_hitos_acreditacion_update ON public.registrados;
CREATE TRIGGER trg_registrados_hitos_acreditacion_update
  AFTER UPDATE OF acreditado ON public.registrados
  FOR EACH ROW EXECUTE FUNCTION public.rpe_notificar_hitos_acreditacion();
