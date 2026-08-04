-- Notificaciones in-app + tokens FCM para push de sistema.
-- Ejecutar en el SQL Editor de Supabase (o aplicar sobre schema.sql).
--
-- Webhook (Dashboard → Database → Webhooks):
--   Tabla: public.notificaciones | Evento: INSERT
--   URL: https://<project-ref>.supabase.co/functions/v1/enviar-push
--   Headers: Authorization: Bearer <SERVICE_ROLE_KEY>
--   Payload: fila insertada (record)

-- ----------------------------------------------------------------
-- 1. Tablas
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notificaciones (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo              text NOT NULL DEFAULT 'registro'
                      CHECK (tipo = ANY (ARRAY[
                        'registro',
                        'acreditacion_20',
                        'acreditacion_50',
                        'acreditacion_80',
                        'acreditacion_100'
                      ])),
  titulo            text NOT NULL,
  cuerpo            text NOT NULL,
  registrado_id     uuid REFERENCES public.registrados (id) ON DELETE SET NULL,
  evento_id         uuid REFERENCES public.eventos (id) ON DELETE SET NULL,
  nombre_registrado text NOT NULL,
  nombre_evento     text NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.notificaciones_leidas (
  usuario_id       uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  notificacion_id  uuid NOT NULL REFERENCES public.notificaciones (id) ON DELETE CASCADE,
  leida_at         timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (usuario_id, notificacion_id)
);

CREATE TABLE IF NOT EXISTS public.notificaciones_ocultas (
  usuario_id       uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  notificacion_id  uuid NOT NULL REFERENCES public.notificaciones (id) ON DELETE CASCADE,
  oculta_at        timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (usuario_id, notificacion_id)
);

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  token       text NOT NULL UNIQUE,
  plataforma  text NOT NULL CHECK (plataforma = ANY (ARRAY['android', 'ios'])),
  updated_at  timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_created_at
  ON public.notificaciones (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notificaciones_ocultas_usuario_id
  ON public.notificaciones_ocultas (usuario_id);

CREATE INDEX IF NOT EXISTS idx_device_tokens_usuario_id
  ON public.device_tokens (usuario_id);

-- Realtime para el inbox in-app.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notificaciones'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones;
  END IF;
END $$;

-- ----------------------------------------------------------------
-- 2. Trigger: nuevo registrado → notificación
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpe_notificar_nuevo_registrado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nombre_evento text;
BEGIN
  SELECT e.nombre INTO v_nombre_evento
  FROM public.eventos e
  WHERE e.id = NEW.evento_id;

  IF v_nombre_evento IS NULL THEN
    v_nombre_evento := 'Evento';
  END IF;

  INSERT INTO public.notificaciones (
    tipo,
    titulo,
    cuerpo,
    registrado_id,
    evento_id,
    nombre_registrado,
    nombre_evento
  ) VALUES (
    'registro',
    'Nuevo registro',
    NEW.nombre_completo || ' se registró a ' || v_nombre_evento,
    NEW.id,
    NEW.evento_id,
    NEW.nombre_completo,
    v_nombre_evento
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_registrados_notificar ON public.registrados;
CREATE TRIGGER trg_registrados_notificar
  AFTER INSERT ON public.registrados
  FOR EACH ROW EXECUTE FUNCTION public.rpe_notificar_nuevo_registrado();

-- Oculta todas las notificaciones existentes para el usuario autenticado.
-- Las futuras seguirán visibles hasta que el usuario las elimine.
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

-- ----------------------------------------------------------------
-- 3. RLS
-- ----------------------------------------------------------------
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones_leidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones_ocultas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rpe_notificaciones_select ON public.notificaciones;
CREATE POLICY rpe_notificaciones_select ON public.notificaciones
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rpe_notificaciones_leidas_select ON public.notificaciones_leidas;
CREATE POLICY rpe_notificaciones_leidas_select ON public.notificaciones_leidas
  FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_notificaciones_leidas_insert ON public.notificaciones_leidas;
CREATE POLICY rpe_notificaciones_leidas_insert ON public.notificaciones_leidas
  FOR INSERT TO authenticated
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_notificaciones_leidas_update ON public.notificaciones_leidas;
CREATE POLICY rpe_notificaciones_leidas_update ON public.notificaciones_leidas
  FOR UPDATE TO authenticated
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

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

DROP POLICY IF EXISTS rpe_device_tokens_select ON public.device_tokens;
CREATE POLICY rpe_device_tokens_select ON public.device_tokens
  FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_device_tokens_insert ON public.device_tokens;
CREATE POLICY rpe_device_tokens_insert ON public.device_tokens
  FOR INSERT TO authenticated
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_device_tokens_update ON public.device_tokens;
CREATE POLICY rpe_device_tokens_update ON public.device_tokens
  FOR UPDATE TO authenticated
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS rpe_device_tokens_delete ON public.device_tokens;
CREATE POLICY rpe_device_tokens_delete ON public.device_tokens
  FOR DELETE TO authenticated
  USING (usuario_id = auth.uid());

GRANT SELECT ON public.notificaciones TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notificaciones_leidas TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.notificaciones_ocultas TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_tokens TO authenticated;
