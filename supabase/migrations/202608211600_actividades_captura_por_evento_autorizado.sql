-- Cierra el acceso transversal a actividades de captura. Admin y organizador
-- mantienen alcance global; user y externo requieren una FK evento_origen_id
-- cuyo evento siga presente en usuarios_eventos. Una coincidencia de nombres
-- nunca concede permisos.

CREATE OR REPLACE FUNCTION public.cl_campana_autorizada(p_campana_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT public.rpe_can_create_content()
      OR EXISTS (
        SELECT 1
        FROM public.eventos_leads el
        WHERE el.id = p_campana_id
          AND el.evento_origen_id IS NOT NULL
          AND public.rpe_puede_operar_evento(el.evento_origen_id)
      );
$$;

REVOKE ALL ON FUNCTION public.cl_campana_autorizada(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cl_campana_autorizada(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.cl_externo_evento_origen_autorizado(uuid)
  FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.cl_externo_campana_autorizada(uuid)
  FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.cl_externo_nombre_campana_autorizado(text)
  FROM PUBLIC, authenticated;

DROP POLICY IF EXISTS cl_eventos_leads_select ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_select ON public.eventos_leads
  FOR SELECT TO authenticated
  USING (
    public.rpe_can_create_content()
    OR (
      evento_origen_id IS NOT NULL
      AND public.rpe_puede_operar_evento(evento_origen_id)
    )
  );

DROP POLICY IF EXISTS cl_eventos_leads_insert ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_insert ON public.eventos_leads
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      public.rpe_can_create_content()
      OR (
        evento_origen_id IS NOT NULL
        AND public.rpe_puede_operar_evento(evento_origen_id)
      )
    )
    AND (perfil_id IS NULL OR perfil_id = auth.uid())
  );

DROP POLICY IF EXISTS cl_leads_select ON public.leads;
CREATE POLICY cl_leads_select ON public.leads
  FOR SELECT TO authenticated
  USING (public.cl_campana_autorizada(evento_id));

DROP POLICY IF EXISTS cl_leads_insert ON public.leads;
CREATE POLICY cl_leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (
    perfil_id = auth.uid()
    AND public.cl_campana_autorizada(evento_id)
  );

DROP POLICY IF EXISTS cl_leads_update ON public.leads;
CREATE POLICY cl_leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (
    public.rpe_can_create_content()
    OR (
      perfil_id = auth.uid()
      AND public.cl_campana_autorizada(evento_id)
    )
  )
  WITH CHECK (
    public.rpe_can_create_content()
    OR (
      perfil_id = auth.uid()
      AND public.cl_campana_autorizada(evento_id)
    )
  );

DROP POLICY IF EXISTS rpe_usuarios_eventos_leads_fijados_select
  ON public.usuarios_eventos_leads_fijados;
CREATE POLICY rpe_usuarios_eventos_leads_fijados_select
  ON public.usuarios_eventos_leads_fijados
  FOR SELECT TO authenticated USING (
    usuario_id = auth.uid()
    AND public.cl_campana_autorizada(evento_lead_id)
  );

DROP POLICY IF EXISTS rpe_usuarios_eventos_leads_fijados_insert
  ON public.usuarios_eventos_leads_fijados;
CREATE POLICY rpe_usuarios_eventos_leads_fijados_insert
  ON public.usuarios_eventos_leads_fijados
  FOR INSERT TO authenticated WITH CHECK (
    usuario_id = auth.uid()
    AND public.cl_campana_autorizada(evento_lead_id)
  );

-- Se conservan las implementaciones previas sin permisos y se publican
-- wrappers con el chequeo nuevo. Así la migración no duplica cientos de líneas
-- de lógica de deduplicación y sigue siendo idempotente.
DO $$
BEGIN
  IF to_regprocedure(
    'public.cl_guardar_lead_sin_scope(uuid,text,text,text,text,text,text,uuid)'
  ) IS NULL THEN
    ALTER FUNCTION public.cl_guardar_lead(
      uuid, text, text, text, text, text, text, uuid
    ) RENAME TO cl_guardar_lead_sin_scope;
  END IF;

  IF to_regprocedure('public.cl_resumen_campana_sin_scope(uuid)') IS NULL THEN
    ALTER FUNCTION public.cl_resumen_campana(uuid)
      RENAME TO cl_resumen_campana_sin_scope;
  END IF;

  IF to_regprocedure(
    'public.cl_buscar_lead_por_email_sin_scope(uuid,text)'
  ) IS NULL THEN
    ALTER FUNCTION public.cl_buscar_lead_por_email(uuid, text)
      RENAME TO cl_buscar_lead_por_email_sin_scope;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.cl_guardar_lead_sin_scope(
  uuid, text, text, text, text, text, text, uuid
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cl_resumen_campana_sin_scope(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cl_buscar_lead_por_email_sin_scope(uuid, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cl_guardar_lead(
  p_evento_id uuid,
  p_nombre_completo text,
  p_empresa text,
  p_cargo text,
  p_telefono text,
  p_email text,
  p_descripcion text,
  p_lead_id uuid DEFAULT NULL
)
RETURNS TABLE (
  resultado text,
  lead_id uuid,
  primer_capturador_nombre text,
  es_propio boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.cl_campana_autorizada(p_evento_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501', MESSAGE = 'Sin acceso a la campaña';
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.cl_guardar_lead_sin_scope(
    p_evento_id,
    p_nombre_completo,
    p_empresa,
    p_cargo,
    p_telefono,
    p_email,
    p_descripcion,
    p_lead_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cl_resumen_campana(p_evento_id uuid)
RETURNS TABLE (total bigint, empresas bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF NOT public.cl_campana_autorizada(p_evento_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501', MESSAGE = 'Sin acceso al resumen de la campaña';
  END IF;

  RETURN QUERY
  SELECT * FROM public.cl_resumen_campana_sin_scope(p_evento_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.cl_buscar_lead_por_email(
  p_evento_id uuid,
  p_email text
)
RETURNS TABLE (
  lead_id uuid,
  capturador_nombre text,
  es_propio boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF NOT public.cl_campana_autorizada(p_evento_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501', MESSAGE = 'Sin acceso a la campaña';
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.cl_buscar_lead_por_email_sin_scope(p_evento_id, p_email);
END;
$$;

REVOKE ALL ON FUNCTION public.cl_guardar_lead(
  uuid, text, text, text, text, text, text, uuid
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cl_guardar_lead(
  uuid, text, text, text, text, text, text, uuid
) TO authenticated;
REVOKE ALL ON FUNCTION public.cl_resumen_campana(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cl_resumen_campana(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.cl_buscar_lead_por_email(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cl_buscar_lead_por_email(uuid, text)
  TO authenticated;

-- Las fotos privadas no pueden actuar como bypass de la RLS de leads. Incluso
-- una foto de un lead propio deja de ser legible/escribible al revocarse la
-- actividad que lo contiene.
CREATE OR REPLACE FUNCTION public.rpe_puede_escribir_imagen(
  p_object_name text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_carpeta text := split_part(COALESCE(p_object_name, ''), '/', 1);
  v_archivo text := split_part(COALESCE(p_object_name, ''), '/', 2);
  v_id_text text := split_part(v_archivo, '.', 1);
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL
    OR p_object_name !~* '^(eventos|perfiles|leads)/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|heic|heif)$'
  THEN
    RETURN false;
  END IF;

  v_id := v_id_text::uuid;
  CASE v_carpeta
    WHEN 'eventos' THEN
      RETURN public.rpe_can_create_content();
    WHEN 'perfiles' THEN
      RETURN v_id = auth.uid() OR public.rpe_is_admin();
    WHEN 'leads' THEN
      RETURN public.rpe_can_create_content() OR EXISTS (
        SELECT 1
        FROM public.leads l
        WHERE l.id = v_id
          AND l.perfil_id = auth.uid()
          AND public.cl_campana_autorizada(l.evento_id)
      );
    ELSE
      RETURN false;
  END CASE;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN false;
END;
$$;

REVOKE ALL ON FUNCTION public.rpe_puede_escribir_imagen(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpe_puede_escribir_imagen(text)
  TO authenticated;

-- Una notificación dirigida tampoco puede conservar el nombre de una
-- actividad después de revocar su evento. Los comentarios nuevos guardan el
-- evento de origen y solo notifican a users que todavía lo tienen asignado.
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
    WHEN p_destinatario_id IS NOT NULL THEN
      p_destinatario_id = auth.uid()
      AND public.rpe_is_internal_user()
      AND (
        public.rpe_can_create_content()
        OR (
          p_evento_id IS NOT NULL
          AND public.rpe_puede_operar_evento(p_evento_id)
        )
      )
    ELSE public.rpe_puede_ver_notificacion(p_evento_id)
  END;
$$;

REVOKE ALL ON FUNCTION public.rpe_puede_ver_notificacion_row(uuid, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpe_puede_ver_notificacion_row(uuid, uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.cl_notificar_comentario_lead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000001';
  v_lead              public.leads%ROWTYPE;
  v_nombre_campana    text;
  v_evento_origen_id  uuid;
  v_cuerpo            text;
  v_destinatarios     uuid[];
BEGIN
  SELECT * INTO v_lead FROM public.leads l WHERE l.id = NEW.lead_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT el.nombre, el.evento_origen_id
  INTO v_nombre_campana, v_evento_origen_id
  FROM public.eventos_leads el
  WHERE el.id = v_lead.evento_id;

  v_nombre_campana := COALESCE(v_nombre_campana, 'Actividad de captura');

  SELECT ARRAY(
    SELECT p.id
    FROM public.perfiles p
    WHERE p.activo = true
      AND p.rol IN ('admin', 'organizador', 'user')
      AND p.id <> v_sentinel
      AND p.id IS DISTINCT FROM NEW.autor_id
      AND (
        p.rol IN ('admin', 'organizador')
        OR (
          p.rol = 'user'
          AND v_evento_origen_id IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM public.usuarios_eventos ue
            WHERE ue.usuario_id = p.id
              AND ue.evento_id = v_evento_origen_id
          )
        )
      )
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

  v_cuerpo := NEW.autor_nombre || ' comentó sobre ' || v_lead.nombre_completo
    || ' (' || v_nombre_campana || ')';

  INSERT INTO public.notificaciones (
    tipo, titulo, cuerpo, destinatario_id,
    lead_id, evento_lead_id, evento_id,
    nombre_registrado, nombre_evento
  )
  SELECT
    'lead_comentario',
    'Nuevo comentario',
    v_cuerpo,
    d.destinatario_id,
    v_lead.id,
    v_lead.evento_id,
    v_evento_origen_id,
    v_lead.nombre_completo,
    v_nombre_campana
  FROM unnest(v_destinatarios) AS d(destinatario_id);

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.cl_notificar_comentario_lead() FROM PUBLIC;
