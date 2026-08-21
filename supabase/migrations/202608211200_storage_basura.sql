-- Cola de objetos de Storage que quedaron sin dueño.
--
-- Borrar una fila de Postgres nunca tocaba el archivo: cada evento eliminado,
-- cada lead borrado y —peor— **cada edición de portada** (la app sube un UUID
-- nuevo en vez de sobrescribir) dejaba un objeto huérfano para siempre.
--
-- El registro lo hacen triggers, porque son lo único que ve también los
-- borrados en cascada, que nunca pasan por la app. El borrado real lo hace la
-- Edge Function `limpiar-storage` con la service role: quitar la fila de
-- `storage.objects` a mano dejaría el archivo físico igualmente ocupando cuota.

-- ---------------------------------------------------------------------------
-- 1. Cola
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.storage_basura (
  id         uuid NOT NULL DEFAULT gen_random_uuid(),
  bucket     text NOT NULL,
  path       text NOT NULL,
  creado_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT storage_basura_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_storage_basura_creado
  ON public.storage_basura (creado_at);

-- Sin políticas a propósito: RLS activo y ninguna regla = solo la service role
-- (que las omite) puede leerla o vaciarla.
ALTER TABLE public.storage_basura ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. Normalización de rutas
-- ---------------------------------------------------------------------------
-- La base guarda tres formas de la misma imagen según de dónde venga: el path
-- canónico (`leads/<uuid>.jpg`), la URL pública del bucket `imagenes` y la URL
-- firmada de `leads-privados`. Espejo exacto de `pathFotoStorageLead` en
-- lib/data/repositories/storage_repository.dart.
CREATE OR REPLACE FUNCTION public.rpe_storage_path(p_url text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_valor text := COALESCE(p_url, '');
  v_marca text;
  v_pos   int;
BEGIN
  IF v_valor = '' THEN
    RETURN NULL;
  END IF;

  -- El `?v=` de invalidación de caché no forma parte del objeto.
  v_valor := split_part(v_valor, '?', 1);

  FOREACH v_marca IN ARRAY ARRAY[
    '/object/public/imagenes/',
    '/object/sign/leads-privados/',
    '/object/public/leads-privados/'
  ] LOOP
    v_pos := position(v_marca IN v_valor);
    IF v_pos > 0 THEN
      RETURN NULLIF(
        replace(
          substring(v_valor FROM v_pos + length(v_marca)),
          '%20', ' '
        ),
        ''
      );
    END IF;
  END LOOP;

  -- Ya venía canónico (`leads/<uuid>.jpg`, `eventos/…`, `perfiles/…`).
  IF v_valor ~ '^(eventos|perfiles|leads)/' THEN
    RETURN v_valor;
  END IF;

  -- Cualquier otra cosa (URL externa, dato viejo) no es nuestra: no se encola.
  RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Encolado
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpe_encolar_storage(
  p_bucket text,
  p_url    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_path text := public.rpe_storage_path(p_url);
BEGIN
  IF v_path IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.storage_basura (bucket, path) VALUES (p_bucket, v_path);
END;
$$;

-- Portadas de eventos y actividades: bucket `imagenes`.
--
-- La actividad de captura **interna** hereda `imagen_url` del evento ligado
-- (ver `rpe_sync_actividad_interna_desde_evento`), así que su path puede seguir
-- en uso por el evento. No se filtra acá: el filtro definitivo vive en
-- `rpe_storage_basura_tomar`, que corre con la transacción ya cerrada y ve la
-- base consistente —a mitad de un borrado en cascada, en cambio, una fila que
-- está a punto de irse todavía se vería viva.
CREATE OR REPLACE FUNCTION public.rpe_storage_basura_portada()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.rpe_encolar_storage('imagenes', OLD.imagen_url);
    RETURN OLD;
  END IF;

  IF NEW.imagen_url IS DISTINCT FROM OLD.imagen_url THEN
    PERFORM public.rpe_encolar_storage('imagenes', OLD.imagen_url);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpe_storage_basura_foto_perfil()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.rpe_encolar_storage('imagenes', OLD.foto_url);
    RETURN OLD;
  END IF;

  IF NEW.foto_url IS DISTINCT FROM OLD.foto_url THEN
    PERFORM public.rpe_encolar_storage('imagenes', OLD.foto_url);
  END IF;
  RETURN NEW;
END;
$$;

-- Fotos de leads: bucket privado `leads-privados`, y son un array.
CREATE OR REPLACE FUNCTION public.rpe_storage_basura_fotos_lead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    FOREACH v_url IN ARRAY COALESCE(OLD.fotos_urls, '{}'::text[]) LOOP
      PERFORM public.rpe_encolar_storage('leads-privados', v_url);
    END LOOP;
    RETURN OLD;
  END IF;

  -- Solo las que dejaron de estar referenciadas por esta fila.
  FOREACH v_url IN ARRAY COALESCE(OLD.fotos_urls, '{}'::text[]) LOOP
    IF NOT (v_url = ANY (COALESCE(NEW.fotos_urls, '{}'::text[]))) THEN
      PERFORM public.rpe_encolar_storage('leads-privados', v_url);
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_eventos_storage_basura ON public.eventos;
CREATE TRIGGER trg_eventos_storage_basura
  AFTER UPDATE OF imagen_url OR DELETE ON public.eventos
  FOR EACH ROW EXECUTE FUNCTION public.rpe_storage_basura_portada();

DROP TRIGGER IF EXISTS trg_eventos_leads_storage_basura ON public.eventos_leads;
CREATE TRIGGER trg_eventos_leads_storage_basura
  AFTER UPDATE OF imagen_url OR DELETE ON public.eventos_leads
  FOR EACH ROW EXECUTE FUNCTION public.rpe_storage_basura_portada();

DROP TRIGGER IF EXISTS trg_perfiles_storage_basura ON public.perfiles;
CREATE TRIGGER trg_perfiles_storage_basura
  AFTER UPDATE OF foto_url OR DELETE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.rpe_storage_basura_foto_perfil();

DROP TRIGGER IF EXISTS trg_leads_storage_basura ON public.leads;
CREATE TRIGGER trg_leads_storage_basura
  AFTER UPDATE OF fotos_urls OR DELETE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.rpe_storage_basura_fotos_lead();

-- ---------------------------------------------------------------------------
-- 4. Drenaje
-- ---------------------------------------------------------------------------
-- ¿Queda alguna fila viva apuntando a este objeto? Cubre el caso de la
-- actividad interna, que comparte portada con su evento, y el de una foto de
-- lead reutilizada.
CREATE OR REPLACE FUNCTION public.rpe_storage_en_uso(
  p_bucket text,
  p_path   text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF p_bucket = 'imagenes' THEN
    RETURN EXISTS (
      SELECT 1 FROM public.eventos
      WHERE public.rpe_storage_path(imagen_url) = p_path
    ) OR EXISTS (
      SELECT 1 FROM public.eventos_leads
      WHERE public.rpe_storage_path(imagen_url) = p_path
    ) OR EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE public.rpe_storage_path(foto_url) = p_path
    );
  END IF;

  IF p_bucket = 'leads-privados' THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.leads l, unnest(l.fotos_urls) AS u(url)
      WHERE public.rpe_storage_path(u.url) = p_path
    );
  END IF;

  -- Bucket desconocido: no se toca.
  RETURN true;
END;
$$;

-- Entrega el siguiente lote realmente huérfano y descarta de la cola lo que
-- resultó seguir en uso. Lo llama `limpiar-storage` con la service role.
--
-- El `DELETE` va en un CTE: Postgres ejecuta los CTE que modifican datos
-- siempre y exactamente una vez, lea o no la consulta principal su salida.
CREATE OR REPLACE FUNCTION public.rpe_storage_basura_tomar(p_limite int DEFAULT 200)
RETURNS TABLE (id uuid, bucket text, path text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH lote AS (
    SELECT b.id, b.bucket, b.path
      FROM public.storage_basura b
     ORDER BY b.creado_at
     LIMIT GREATEST(COALESCE(p_limite, 200), 1)
  ),
  vivas AS (
    SELECT l.id
      FROM lote l
     WHERE public.rpe_storage_en_uso(l.bucket, l.path)
  ),
  descartadas AS (
    DELETE FROM public.storage_basura b
     WHERE b.id IN (SELECT v.id FROM vivas v)
    RETURNING b.id
  )
  SELECT l.id, l.bucket, l.path
    FROM lote l
   WHERE l.id NOT IN (SELECT v.id FROM vivas v);
$$;

REVOKE ALL ON FUNCTION public.rpe_storage_basura_tomar(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpe_storage_en_uso(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpe_encolar_storage(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpe_storage_basura_tomar(int) TO service_role;
