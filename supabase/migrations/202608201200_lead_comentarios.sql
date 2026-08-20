-- Hilo de comentarios por lead + lectura de leads ajenos para el externo
-- autorizado en la campaña. Idempotente: también vive en supabase/schema.sql.

-- ----------------------------------------------------------------
-- Tabla
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.lead_comentarios (
  id           uuid NOT NULL DEFAULT gen_random_uuid(),
  lead_id      uuid NOT NULL,
  autor_id     uuid,
  autor_nombre text NOT NULL DEFAULT 'Sin identificar',
  cuerpo       text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT lead_comentarios_pkey PRIMARY KEY (id),
  CONSTRAINT lead_comentarios_lead_id_fkey FOREIGN KEY (lead_id)
    REFERENCES public.leads (id) ON DELETE CASCADE,
  CONSTRAINT lead_comentarios_autor_id_fkey FOREIGN KEY (autor_id)
    REFERENCES public.perfiles (id),
  CONSTRAINT lead_comentarios_cuerpo_check CHECK (
    char_length(btrim(cuerpo)) BETWEEN 1 AND 1000
  )
);

CREATE INDEX IF NOT EXISTS idx_lead_comentarios_lead_created
  ON public.lead_comentarios (lead_id, created_at);

ALTER TABLE public.lead_comentarios ENABLE ROW LEVEL SECURITY;

-- Autoría inmutable: el cliente no elige el autor ni reescribe el cuerpo.
CREATE OR REPLACE FUNCTION public.cl_set_lead_comentario_server_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Los comentarios no se editan; bórralo y escribe uno nuevo';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    NEW.autor_id := auth.uid();
  END IF;

  SELECT COALESCE(NULLIF(btrim(p.nombre_completo), ''), 'Sin identificar')
  INTO NEW.autor_nombre
  FROM public.perfiles p
  WHERE p.id = NEW.autor_id;

  IF NOT FOUND THEN
    NEW.autor_nombre := 'Sin identificar';
  END IF;

  NEW.cuerpo := btrim(NEW.cuerpo);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lead_comentarios_server_fields ON public.lead_comentarios;
CREATE TRIGGER trg_lead_comentarios_server_fields
  BEFORE INSERT OR UPDATE ON public.lead_comentarios
  FOR EACH ROW
  EXECUTE FUNCTION public.cl_set_lead_comentario_server_fields();

-- ----------------------------------------------------------------
-- Leads: el externo autorizado ve todos los de su campaña, no solo los suyos.
-- El email y el teléfono siguen enmascarados en la app (mismo trato que `user`).
-- ----------------------------------------------------------------
DROP POLICY IF EXISTS cl_leads_select ON public.leads;
CREATE POLICY cl_leads_select ON public.leads
  FOR SELECT TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR perfil_id = auth.uid()
    OR public.cl_externo_campana_autorizada(evento_id)
  );

-- ----------------------------------------------------------------
-- Comentarios: quien puede ver el lead puede leer y publicar; solo el autor borra.
-- ----------------------------------------------------------------
DROP POLICY IF EXISTS cl_lead_comentarios_select ON public.lead_comentarios;
CREATE POLICY cl_lead_comentarios_select ON public.lead_comentarios
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.id = lead_id
    )
  );

DROP POLICY IF EXISTS cl_lead_comentarios_insert ON public.lead_comentarios;
CREATE POLICY cl_lead_comentarios_insert ON public.lead_comentarios
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.id = lead_id
    )
  );

DROP POLICY IF EXISTS cl_lead_comentarios_delete ON public.lead_comentarios;
CREATE POLICY cl_lead_comentarios_delete ON public.lead_comentarios
  FOR DELETE TO authenticated
  USING (autor_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON public.lead_comentarios TO authenticated;

-- ----------------------------------------------------------------
-- Lookup de duplicado al escanear (misma normalización que cl_guardar_lead).
-- ----------------------------------------------------------------
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
DECLARE
  v_usuario_id uuid := auth.uid();
  v_rol text;
  v_activo boolean;
  v_email_normalizado text := NULLIF(lower(btrim(p_email)), '');
  v_existente public.leads%ROWTYPE;
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'No autenticado';
  END IF;

  SELECT p.rol, p.activo
  INTO v_rol, v_activo
  FROM public.perfiles p
  WHERE p.id = v_usuario_id;

  IF NOT FOUND OR v_activo IS NOT TRUE THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Usuario inactivo o sin perfil';
  END IF;

  IF p_evento_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.eventos_leads el WHERE el.id = p_evento_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Campaña no encontrada';
  END IF;

  IF v_rol NOT IN ('admin', 'organizador', 'user')
     AND NOT (
       v_rol = 'externo'
       AND public.cl_externo_campana_autorizada(p_evento_id)
     ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sin acceso a la campaña';
  END IF;

  IF v_email_normalizado IS NULL THEN
    RETURN;
  END IF;

  SELECT l.* INTO v_existente
  FROM public.leads l
  WHERE l.evento_id = p_evento_id
    AND NULLIF(lower(btrim(l.email)), '') = v_email_normalizado
  ORDER BY l.created_at NULLS LAST, l.id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  lead_id := v_existente.id;
  capturador_nombre := v_existente.capturador_nombre;
  es_propio := v_existente.perfil_id = v_usuario_id;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.cl_buscar_lead_por_email(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cl_buscar_lead_por_email(uuid, text)
  TO authenticated;

-- Al borrar un usuario, los comentarios conservan el texto y el nombre
-- denormalizado; la FK de autor pasa al perfil sentinel.
CREATE OR REPLACE FUNCTION public.rpe_eliminar_usuario(usuario_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000001';
  v_usuario_id uuid := usuario_id;
BEGIN
  IF usuario_id = v_sentinel THEN
    RAISE EXCEPTION 'No se puede eliminar el perfil sistema';
  END IF;

  IF NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede eliminar usuarios';
  END IF;

  IF usuario_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes eliminar tu propia cuenta';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'registrados'
      AND column_name = 'acreditado_por'
  ) THEN
    UPDATE public.registrados
    SET acreditado_por = v_sentinel
    WHERE acreditado_por = usuario_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'registrados' AND column_name = 'ingresado_por'
  ) THEN
    UPDATE public.registrados
    SET ingresado_por = v_sentinel
    WHERE ingresado_por = usuario_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'eventos' AND column_name = 'creado_por'
  ) THEN
    UPDATE public.eventos
    SET creado_por = v_sentinel
    WHERE creado_por = usuario_id;
  END IF;

  IF to_regclass('public.usuarios_eventos') IS NOT NULL THEN
    DELETE FROM public.usuarios_eventos ue
      WHERE ue.usuario_id = v_usuario_id;
  END IF;

  IF to_regclass('public.eventos_leads') IS NOT NULL THEN
    UPDATE public.eventos_leads
    SET perfil_id = v_sentinel
    WHERE perfil_id = usuario_id;
  END IF;
  IF to_regclass('public.leads') IS NOT NULL THEN
    UPDATE public.leads
    SET perfil_id = v_sentinel
    WHERE perfil_id = usuario_id;
  END IF;
  IF to_regclass('public.lead_comentarios') IS NOT NULL THEN
    UPDATE public.lead_comentarios
    SET autor_id = v_sentinel
    WHERE autor_id = usuario_id;
  END IF;

  DELETE FROM public.perfiles WHERE id = usuario_id;

  BEGIN
    DELETE FROM auth.users WHERE id = usuario_id;
  EXCEPTION WHEN foreign_key_violation THEN
    UPDATE auth.users SET banned_until = 'infinity' WHERE id = usuario_id;
    RETURN 'desactivado';
  END;

  RETURN 'eliminado';
END;
$$;
