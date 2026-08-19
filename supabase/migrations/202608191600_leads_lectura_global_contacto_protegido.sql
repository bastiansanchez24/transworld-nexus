-- Leads: el rol interno `user` lee todos los leads de la campaña pero no puede
-- cambiar el contacto de ninguno (ni el de los propios). El email y el teléfono
-- se le muestran enmascarados en la app.
-- Idempotente: también vive en supabase/schema.sql.

DROP POLICY IF EXISTS cl_leads_select ON public.leads;
CREATE POLICY cl_leads_select ON public.leads
  FOR SELECT TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR perfil_id = auth.uid()
  );

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
DECLARE
  v_usuario_id uuid := auth.uid();
  v_rol text;
  v_activo boolean;
  v_capturador_nombre text;
  v_email text := NULLIF(btrim(p_email), '');
  v_email_normalizado text := NULLIF(lower(btrim(p_email)), '');
  v_telefono text := NULLIF(btrim(p_telefono), '');
  v_lead_id uuid := COALESCE(p_lead_id, gen_random_uuid());
  v_existente public.leads%ROWTYPE;
  v_duplicado public.leads%ROWTYPE;
  v_guardado public.leads%ROWTYPE;
  v_puede_editar_global boolean;
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'No autenticado';
  END IF;

  SELECT
    p.rol,
    p.activo,
    COALESCE(NULLIF(btrim(p.nombre_completo), ''), 'Sin identificar')
  INTO v_rol, v_activo, v_capturador_nombre
  FROM public.perfiles p
  WHERE p.id = v_usuario_id;

  IF NOT FOUND OR v_activo IS NOT TRUE THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Usuario inactivo o sin perfil';
  END IF;

  v_puede_editar_global := v_rol IN ('admin', 'organizador');

  IF NOT EXISTS (
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

  IF NULLIF(btrim(p_nombre_completo), '') IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'El nombre es obligatorio';
  END IF;

  -- La fila se carga antes de validar el email porque quien no edita de forma
  -- global tampoco puede cambiar el contacto: su email y teléfono se reemplazan
  -- por los ya guardados, y son esos los que se validan y se buscan duplicados.
  IF p_lead_id IS NOT NULL THEN
    SELECT l.* INTO v_existente
    FROM public.leads l
    WHERE l.id = p_lead_id
    FOR UPDATE;

    IF FOUND THEN
      IF v_existente.evento_id <> p_evento_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'El lead pertenece a otra campaña';
      END IF;
      IF NOT v_puede_editar_global
         AND v_existente.perfil_id IS DISTINCT FROM v_usuario_id THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Solo puedes editar tus propios leads';
      END IF;
      IF NOT v_puede_editar_global THEN
        v_email := NULLIF(btrim(v_existente.email), '');
        v_email_normalizado := NULLIF(lower(btrim(v_existente.email)), '');
        v_telefono := NULLIF(btrim(v_existente.telefono), '');
      END IF;
    END IF;
  END IF;

  IF v_email IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'El email es obligatorio';
  END IF;

  IF v_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'El email no es válido';
  END IF;

  -- Serializa por campaña+email. El índice único sigue siendo la última línea
  -- de defensa para escrituras directas y clientes concurrentes.
  IF v_email_normalizado IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(
      hashtextextended(p_evento_id::text || ':' || v_email_normalizado, 0)
    );
  END IF;

  IF v_email_normalizado IS NOT NULL THEN
    SELECT l.* INTO v_duplicado
    FROM public.leads l
    WHERE l.evento_id = p_evento_id
      AND l.id IS DISTINCT FROM v_lead_id
      AND NULLIF(lower(btrim(l.email)), '') = v_email_normalizado
    ORDER BY l.created_at NULLS LAST, l.id
    LIMIT 1;

    IF FOUND THEN
      RETURN QUERY SELECT
        'duplicado'::text,
        v_duplicado.id,
        v_duplicado.capturador_nombre,
        v_duplicado.perfil_id = v_usuario_id;
      RETURN;
    END IF;
  END IF;

  IF v_existente.id IS NOT NULL THEN
    UPDATE public.leads l
    SET nombre_completo = btrim(p_nombre_completo),
        empresa = NULLIF(btrim(p_empresa), ''),
        cargo = NULLIF(btrim(p_cargo), ''),
        telefono = v_telefono,
        email = v_email,
        descripcion = NULLIF(btrim(p_descripcion), '')
    WHERE l.id = v_existente.id
    RETURNING l.* INTO v_guardado;

    RETURN QUERY SELECT
      'actualizado'::text,
      v_guardado.id,
      v_guardado.capturador_nombre,
      v_guardado.perfil_id = v_usuario_id;
    RETURN;
  END IF;

  INSERT INTO public.leads (
    id,
    evento_id,
    nombre_completo,
    empresa,
    cargo,
    telefono,
    email,
    descripcion,
    perfil_id,
    capturador_nombre
  ) VALUES (
    v_lead_id,
    p_evento_id,
    btrim(p_nombre_completo),
    NULLIF(btrim(p_empresa), ''),
    NULLIF(btrim(p_cargo), ''),
    v_telefono,
    v_email,
    NULLIF(btrim(p_descripcion), ''),
    v_usuario_id,
    v_capturador_nombre
  )
  RETURNING * INTO v_guardado;

  RETURN QUERY SELECT
    'creado'::text,
    v_guardado.id,
    v_guardado.capturador_nombre,
    true;
  RETURN;
EXCEPTION
  WHEN unique_violation THEN
    SELECT l.* INTO v_duplicado
    FROM public.leads l
    WHERE l.evento_id = p_evento_id
      AND l.id IS DISTINCT FROM v_lead_id
      AND NULLIF(lower(btrim(l.email)), '') = v_email_normalizado
    ORDER BY l.created_at NULLS LAST, l.id
    LIMIT 1;

    IF FOUND THEN
      RETURN QUERY SELECT
        'duplicado'::text,
        v_duplicado.id,
        v_duplicado.capturador_nombre,
        v_duplicado.perfil_id = v_usuario_id;
      RETURN;
    END IF;
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.cl_guardar_lead(
  uuid, text, text, text, text, text, text, uuid
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cl_guardar_lead(
  uuid, text, text, text, text, text, text, uuid
) TO authenticated;
