-- Comentarios: snapshot de rol, edición de cuerpo, borrar admin/organizador.
-- Idempotente: también vive en supabase/schema.sql.

ALTER TABLE public.lead_comentarios
  ADD COLUMN IF NOT EXISTS autor_rol text;

ALTER TABLE public.lead_comentarios
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

UPDATE public.lead_comentarios c
SET autor_rol = p.rol
FROM public.perfiles p
WHERE c.autor_id = p.id
  AND (c.autor_rol IS NULL OR btrim(c.autor_rol) = '');

UPDATE public.lead_comentarios
SET updated_at = created_at
WHERE updated_at IS NULL;

ALTER TABLE public.lead_comentarios
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now());

CREATE OR REPLACE FUNCTION public.cl_set_lead_comentario_server_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nombre text;
  v_rol text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Reasignar autor (p. ej. sentinel al borrar usuario): no es edición.
    IF NEW.cuerpo IS NOT DISTINCT FROM OLD.cuerpo
       AND NEW.lead_id IS NOT DISTINCT FROM OLD.lead_id THEN
      NEW.updated_at := OLD.updated_at;
      RETURN NEW;
    END IF;

    NEW.id := OLD.id;
    NEW.lead_id := OLD.lead_id;
    NEW.autor_id := OLD.autor_id;
    NEW.autor_nombre := OLD.autor_nombre;
    NEW.autor_rol := OLD.autor_rol;
    NEW.created_at := OLD.created_at;
    NEW.cuerpo := btrim(NEW.cuerpo);
    NEW.updated_at := timezone('utc', now());
    RETURN NEW;
  END IF;

  IF auth.uid() IS NOT NULL THEN
    NEW.autor_id := auth.uid();
  END IF;

  SELECT
    COALESCE(NULLIF(btrim(p.nombre_completo), ''), 'Sin identificar'),
    p.rol
  INTO v_nombre, v_rol
  FROM public.perfiles p
  WHERE p.id = NEW.autor_id;

  IF NOT FOUND THEN
    NEW.autor_nombre := 'Sin identificar';
    NEW.autor_rol := NULL;
  ELSE
    NEW.autor_nombre := v_nombre;
    NEW.autor_rol := v_rol;
  END IF;

  NEW.cuerpo := btrim(NEW.cuerpo);
  NEW.updated_at := COALESCE(NEW.created_at, timezone('utc', now()));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lead_comentarios_server_fields ON public.lead_comentarios;
CREATE TRIGGER trg_lead_comentarios_server_fields
  BEFORE INSERT OR UPDATE ON public.lead_comentarios
  FOR EACH ROW
  EXECUTE FUNCTION public.cl_set_lead_comentario_server_fields();

DROP POLICY IF EXISTS cl_lead_comentarios_update ON public.lead_comentarios;
CREATE POLICY cl_lead_comentarios_update ON public.lead_comentarios
  FOR UPDATE TO authenticated
  USING (autor_id = auth.uid())
  WITH CHECK (autor_id = auth.uid());

DROP POLICY IF EXISTS cl_lead_comentarios_delete ON public.lead_comentarios;
CREATE POLICY cl_lead_comentarios_delete ON public.lead_comentarios
  FOR DELETE TO authenticated
  USING (
    autor_id = auth.uid()
    OR public.rpe_is_admin()
    OR public.rpe_is_organizador()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lead_comentarios TO authenticated;
