-- Notificaciones dirigidas a un usuario + aviso de comentarios en leads,
-- y listado histórico de acreditaciones propias.
-- Idempotente: también vive en supabase/schema.sql.

-- ----------------------------------------------------------------
-- 1. `notificaciones` deja de ser solo broadcast
--    `destinatario_id IS NULL` = aviso global (comportamiento anterior).
-- ----------------------------------------------------------------
ALTER TABLE public.notificaciones
  ADD COLUMN IF NOT EXISTS destinatario_id uuid,
  ADD COLUMN IF NOT EXISTS lead_id uuid,
  ADD COLUMN IF NOT EXISTS evento_lead_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'notificaciones_destinatario_id_fkey'
  ) THEN
    ALTER TABLE public.notificaciones
      ADD CONSTRAINT notificaciones_destinatario_id_fkey
      FOREIGN KEY (destinatario_id)
      REFERENCES public.perfiles (id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notificaciones_lead_id_fkey'
  ) THEN
    ALTER TABLE public.notificaciones
      ADD CONSTRAINT notificaciones_lead_id_fkey
      FOREIGN KEY (lead_id)
      REFERENCES public.leads (id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'notificaciones_evento_lead_id_fkey'
  ) THEN
    ALTER TABLE public.notificaciones
      ADD CONSTRAINT notificaciones_evento_lead_id_fkey
      FOREIGN KEY (evento_lead_id)
      REFERENCES public.eventos_leads (id) ON DELETE CASCADE;
  END IF;
END;
$$;

-- El CHECK de `tipo` no contemplaba comentarios.
ALTER TABLE public.notificaciones
  DROP CONSTRAINT IF EXISTS notificaciones_tipo_check;
ALTER TABLE public.notificaciones
  ADD CONSTRAINT notificaciones_tipo_check CHECK (tipo = ANY (ARRAY[
    'registro',
    'acreditacion_20',
    'acreditacion_50',
    'acreditacion_80',
    'acreditacion_100',
    'lead_comentario'
  ]));

CREATE INDEX IF NOT EXISTS idx_notificaciones_destinatario
  ON public.notificaciones (destinatario_id, created_at DESC)
  WHERE destinatario_id IS NOT NULL;

-- ----------------------------------------------------------------
-- 2. Visibilidad: un aviso dirigido lo ve su destinatario y nadie más.
--    Los globales conservan la regla por evento de rpe_puede_ver_notificacion.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpe_puede_ver_notificacion_row(
  p_evento_id uuid,
  p_destinatario_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT CASE
    WHEN p_destinatario_id IS NOT NULL THEN p_destinatario_id = auth.uid()
    ELSE public.rpe_puede_ver_notificacion(p_evento_id)
  END;
$$;

GRANT EXECUTE ON FUNCTION public.rpe_puede_ver_notificacion_row(uuid, uuid)
  TO authenticated;

DROP POLICY IF EXISTS rpe_notificaciones_select ON public.notificaciones;
CREATE POLICY rpe_notificaciones_select ON public.notificaciones
  FOR SELECT TO authenticated
  USING (public.rpe_puede_ver_notificacion_row(evento_id, destinatario_id));

DROP POLICY IF EXISTS rpe_notificaciones_leidas_select ON public.notificaciones_leidas;
CREATE POLICY rpe_notificaciones_leidas_select ON public.notificaciones_leidas
  FOR SELECT TO authenticated
  USING (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  );

DROP POLICY IF EXISTS rpe_notificaciones_leidas_insert ON public.notificaciones_leidas;
CREATE POLICY rpe_notificaciones_leidas_insert ON public.notificaciones_leidas
  FOR INSERT TO authenticated
  WITH CHECK (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  );

DROP POLICY IF EXISTS rpe_notificaciones_leidas_update ON public.notificaciones_leidas;
CREATE POLICY rpe_notificaciones_leidas_update ON public.notificaciones_leidas
  FOR UPDATE TO authenticated
  USING (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  )
  WITH CHECK (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  );

DROP POLICY IF EXISTS rpe_notificaciones_ocultas_select ON public.notificaciones_ocultas;
CREATE POLICY rpe_notificaciones_ocultas_select ON public.notificaciones_ocultas
  FOR SELECT TO authenticated
  USING (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  );

DROP POLICY IF EXISTS rpe_notificaciones_ocultas_insert ON public.notificaciones_ocultas;
CREATE POLICY rpe_notificaciones_ocultas_insert ON public.notificaciones_ocultas
  FOR INSERT TO authenticated
  WITH CHECK (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  );

DROP POLICY IF EXISTS rpe_notificaciones_ocultas_delete ON public.notificaciones_ocultas;
CREATE POLICY rpe_notificaciones_ocultas_delete ON public.notificaciones_ocultas
  FOR DELETE TO authenticated
  USING (
    usuario_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id = notificacion_id
        AND public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
    )
  );

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
  IF NOT public.rpe_is_internal_user() THEN
    RAISE EXCEPTION 'No tienes acceso a notificaciones';
  END IF;

  INSERT INTO public.notificaciones_ocultas (usuario_id, notificacion_id)
  SELECT v_user_id, n.id
  FROM public.notificaciones n
  WHERE public.rpe_puede_ver_notificacion_row(n.evento_id, n.destinatario_id)
  ON CONFLICT (usuario_id, notificacion_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpe_ocultar_todas_notificaciones() TO authenticated;

-- ----------------------------------------------------------------
-- 3. Aviso de comentario en un lead
--    Destinatarios: el capturador del lead y todos los que ya comentaron,
--    menos el autor del comentario nuevo.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cl_notificar_comentario_lead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000001';
  v_lead           public.leads%ROWTYPE;
  v_nombre_campana text;
  v_cuerpo         text;
  v_destinatarios  uuid[];
BEGIN
  SELECT * INTO v_lead FROM public.leads l WHERE l.id = NEW.lead_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- El destinatario debe seguir siendo un usuario interno activo: si se dio de
  -- baja o pasó a externo, la notificación no tendría dónde mostrarse.
  SELECT ARRAY(
    SELECT p.id
    FROM public.perfiles p
    WHERE p.activo = true
      AND p.rol IN ('admin', 'organizador', 'user')
      AND p.id <> v_sentinel
      AND p.id IS DISTINCT FROM NEW.autor_id
      AND (
        p.id = v_lead.perfil_id
        OR EXISTS (
          SELECT 1
          FROM public.lead_comentarios c
          WHERE c.lead_id = NEW.lead_id
            AND c.autor_id = p.id
        )
      )
  ) INTO v_destinatarios;

  IF v_destinatarios IS NULL OR cardinality(v_destinatarios) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT el.nombre INTO v_nombre_campana
  FROM public.eventos_leads el
  WHERE el.id = v_lead.evento_id;

  v_nombre_campana := COALESCE(v_nombre_campana, 'Actividad de captura');

  v_cuerpo := NEW.autor_nombre || ' comentó sobre ' || v_lead.nombre_completo
    || ' (' || v_nombre_campana || ')';

  INSERT INTO public.notificaciones (
    tipo, titulo, cuerpo, destinatario_id,
    lead_id, evento_lead_id,
    nombre_registrado, nombre_evento
  )
  SELECT
    'lead_comentario',
    'Nuevo comentario',
    v_cuerpo,
    d.destinatario_id,
    v_lead.id,
    v_lead.evento_id,
    v_lead.nombre_completo,
    v_nombre_campana
  FROM unnest(v_destinatarios) AS d(destinatario_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lead_comentarios_notificar ON public.lead_comentarios;
CREATE TRIGGER trg_lead_comentarios_notificar
  AFTER INSERT ON public.lead_comentarios
  FOR EACH ROW EXECUTE FUNCTION public.cl_notificar_comentario_lead();

-- ----------------------------------------------------------------
-- 4. Acreditaciones propias, con historia completa
--    `rpe_registrados_select` y `rpe_eventos_select` acotan a
--    `rpe_puede_operar_evento`: sin este RPC, a un `user` al que le retiraron
--    un evento le desaparecerían acreditaciones que sí hizo.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpe_mis_acreditados()
RETURNS TABLE (
  evento_id       uuid,
  evento_nombre   text,
  evento_fecha    date,
  registrado_id   uuid,
  nombre_completo text,
  empresa         text,
  cargo           text,
  acreditado_en   timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    r.evento_id,
    COALESCE(e.nombre, 'Evento eliminado'),
    e.fecha,
    r.id,
    r.nombre_completo,
    r.empresa,
    r.cargo,
    r.acreditado_en
  FROM public.registrados r
  LEFT JOIN public.eventos e ON e.id = r.evento_id
  WHERE auth.uid() IS NOT NULL
    AND r.acreditado_por = auth.uid()
  ORDER BY e.fecha DESC NULLS LAST, r.acreditado_en DESC NULLS LAST;
$$;

REVOKE ALL ON FUNCTION public.rpe_mis_acreditados() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpe_mis_acreditados() TO authenticated;

-- ----------------------------------------------------------------
-- 5. Realtime del inbox: sin esto el badge no se actualiza en vivo
--    (notificacionesRealtimeSubscriptionProvider escucha INSERT).
-- ----------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'notificaciones'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones;
  END IF;
END;
$$;
