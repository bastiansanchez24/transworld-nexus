-- Normaliza el email de registrados (identificador irrepetible) y evita
-- duplicados por capitalización o doble click en el formulario.

BEGIN;

-- Minúsculas solo en correos que no colisionan con otro del mismo evento.
-- Los duplicados históricos se dejan como están: un índice UNIQUE nuevo
-- sobre lower(email) fallaría, y no se reescriben ni se borran filas.
UPDATE public.registrados r
SET email = lower(trim(r.email))
WHERE r.email IS DISTINCT FROM lower(trim(r.email))
  AND NOT EXISTS (
    SELECT 1
    FROM public.registrados o
    WHERE o.evento_id = r.evento_id
      AND o.id <> r.id
      AND lower(trim(o.email)) = lower(trim(r.email))
  );

CREATE OR REPLACE FUNCTION public.rpe_normalizar_email_registrado()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.email := lower(trim(NEW.email));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_registrados_normalizar_email ON public.registrados;
CREATE TRIGGER trg_registrados_normalizar_email
  BEFORE INSERT OR UPDATE OF email ON public.registrados
  FOR EACH ROW EXECUTE FUNCTION public.rpe_normalizar_email_registrado();

CREATE OR REPLACE FUNCTION public.rpe_existe_email_registrado(
  p_evento_id uuid,
  p_email text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.registrados
    WHERE evento_id = p_evento_id
      AND lower(trim(email)) = lower(trim(p_email))
  );
$$;

REVOKE ALL ON FUNCTION public.rpe_existe_email_registrado(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpe_existe_email_registrado(uuid, text)
  TO anon, authenticated;

COMMIT;
