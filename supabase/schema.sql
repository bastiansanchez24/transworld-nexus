-- ============================================================
--  Transworld Nexus — esquema + RLS (CONSOLIDADO, fuente única)
--  (proyecto anteriormente conocido como "Registro Pro")
--  Esquema: public (según definición del proyecto).
--
--  Este archivo es la FUSIÓN de todas las migraciones sueltas que
--  antes vivían en supabase/migracion_*.sql. Refleja el estado final
--  acordado (la política más reciente gana ante conflictos), en orden
--  de dependencias, y es válido tanto en una base de datos NUEVA como
--  sobre la de producción ya existente.
--
--  Migraciones fusionadas aquí (orden cronológico):
--    fusion_leads · leads_policies · registrados_columnas ·
--    fix_invite_externo · roles_4_usuarios · obtener_email_usuario ·
--    auth_user_id_por_email · eliminar_usuario (+ reasignar_todas_fks) ·
--    campana_qr_roles · externo_multi_eventos · externo_leads_amarrados ·
--    delete_solo_admin.
--
--  Es idempotente y (en su mayoría) no destructivo: usa
--  IF NOT EXISTS / OR REPLACE. Las correcciones de RLS SÍ
--  reemplazan políticas anteriores (DROP POLICY IF EXISTS + CREATE).
--
--  ⚠️ Esta base de datos puede seguir compartida con el proyecto
--  hermano "capturador-leads" (mismo project_ref). Las políticas y
--  funciones mantienen el prefijo "rpe_" / "rpe" para no chocar con
--  objetos de ese otro proyecto. Revisar antes de ejecutar en el
--  proyecto real si "capturador-leads" ya tiene políticas propias
--  sobre estas tablas.
--
--  Resumen de correcciones respecto al schema legado (ver doc):
--   1. CRÍTICO: perfiles.rol ya no es auto-editable (trigger BEFORE
--      UPDATE bloquea el cambio de rol salvo que lo haga un admin).
--   2. RLS por rol: admin gestiona usuarios; organizador crea contenido;
--      usuario opera sin crear; externo solo eventos autorizados vía
--      usuarios_eventos (evento_asignado_id = activo/preferido).
--   3. Constraint UNIQUE(evento_id, email) en registrados: los
--      duplicados ahora fallan también a nivel de base de datos,
--      no solo por chequeos de la app.
--   4. Tabla usuarios_eventos (M:N usuario↔evento; rol_evento incluye
--      'externo' para autorizaciones de usuarios externos).
--   5. Política dedicada y acotada de INSERT anónimo en registrados
--      para el flujo de "registro por cliente" (autoregistro público),
--      limitada a eventos activos y con columnas mínimas obligatorias,
--      en vez de depender de un formulario externo fuera de este
--      repositorio (ver Sección 17.5 de la auditoría).
--   6. Función helper is_admin() SECURITY DEFINER para no repetir
--      subconsultas y evitar recursión de RLS.
-- ============================================================

-- ----------------------------------------------------------------
-- 0. Extensiones necesarias
-- ----------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_uuid()

-- ----------------------------------------------------------------
-- 1. TABLAS
-- ----------------------------------------------------------------
-- ⚠️ perfiles ↔ eventos es una dependencia CIRCULAR:
--    eventos.creado_por          → perfiles.id
--    perfiles.evento_asignado_id → eventos.id
-- No se puede declarar ambos FKs inline. Por eso perfiles se crea SIN el FK
-- a eventos; ese FK se agrega más abajo, tras crear public.eventos (bloque
-- "FK circular"). Así el script es válido también en una base de datos nueva
-- (antes fallaba con "relation public.eventos does not exist").
CREATE TABLE IF NOT EXISTS public.perfiles (
  id              uuid NOT NULL,
  nombre_completo text,
  rol             text NOT NULL DEFAULT 'user'
                    CHECK (rol = ANY (ARRAY['admin', 'organizador', 'user', 'externo'])),
  evento_asignado_id uuid,
  cambiar_pass    boolean NOT NULL DEFAULT false,
  activo          boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT perfiles_pkey PRIMARY KEY (id),
  CONSTRAINT perfiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE
);

-- Migración suave: legacy vendedor → user; 4 roles globales.
UPDATE public.perfiles SET rol = 'user' WHERE rol = 'vendedor';
ALTER TABLE public.perfiles ADD COLUMN IF NOT EXISTS evento_asignado_id uuid;
ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS perfiles_rol_check;
ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_rol_check
  CHECK (rol = ANY (ARRAY['admin', 'organizador', 'user', 'externo']));
ALTER TABLE public.perfiles ALTER COLUMN rol SET DEFAULT 'user';
CREATE INDEX IF NOT EXISTS idx_perfiles_evento_asignado
  ON public.perfiles (evento_asignado_id)
  WHERE evento_asignado_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.eventos (
  id                          uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre                      text NOT NULL,
  pais                        text,
  fecha                       date NOT NULL,
  tematica                    text,
  creado_por                  uuid,
  direccion                   text,
  lugar                       text,
  certificacion_capacitacion  boolean NOT NULL DEFAULT false,
  activo                      boolean NOT NULL DEFAULT true,
  imagen_url                  text,
  tipo_registro               text NOT NULL DEFAULT 'comercial'
                                 CHECK (tipo_registro = ANY (ARRAY['comercial', 'cliente'])),
  created_at                  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at                  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT eventos_pkey PRIMARY KEY (id),
  CONSTRAINT eventos_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.perfiles (id) ON DELETE SET NULL
);

-- FK circular perfiles.evento_asignado_id → eventos: se agrega ahora que
-- ambas tablas existen. Idempotente (solo si aún no está creada).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'perfiles_evento_asignado_id_fkey'
  ) THEN
    ALTER TABLE public.perfiles
      ADD CONSTRAINT perfiles_evento_asignado_id_fkey
      FOREIGN KEY (evento_asignado_id) REFERENCES public.eventos (id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.registrados (
  id                          uuid NOT NULL DEFAULT gen_random_uuid(),
  evento_id                   uuid NOT NULL,
  nombre_completo             text NOT NULL,
  email                       text NOT NULL,
  acreditado                  boolean NOT NULL DEFAULT false,
  acreditado_en               timestamptz,
  acreditado_por              uuid,
  rut                         text,
  patente                     text,
  empresa                     text,
  cargo                       text,
  telefono                    text,
  origen                      text NOT NULL DEFAULT 'app'
                                 CHECK (origen = ANY (ARRAY['app', 'excel', 'publico'])),
  ingresado_por               uuid,
  email_confirmacion_enviado  boolean NOT NULL DEFAULT false,
  created_at                  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at                  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT registrados_pkey PRIMARY KEY (id),
  CONSTRAINT registrados_evento_id_fkey FOREIGN KEY (evento_id) REFERENCES public.eventos (id) ON DELETE CASCADE,
  CONSTRAINT registrados_ingresado_por_fkey FOREIGN KEY (ingresado_por) REFERENCES public.perfiles (id) ON DELETE SET NULL,
  CONSTRAINT registrados_acreditado_por_fkey FOREIGN KEY (acreditado_por) REFERENCES public.perfiles (id) ON DELETE SET NULL,
  -- Corrige el riesgo "Sin constraints de duplicados" (doc Sección 8.2/17.7):
  -- ahora la unicidad se garantiza en la base de datos, no solo en la app.
  CONSTRAINT registrados_evento_email_unique UNIQUE (evento_id, email)
);

-- Autorizaciones usuario↔evento (M:N). Para rol global `externo`,
-- `rol_evento = 'externo'` define los eventos operables; el activo/preferido
-- sigue en perfiles.evento_asignado_id.
CREATE TABLE IF NOT EXISTS public.usuarios_eventos (
  usuario_id  uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  evento_id   uuid NOT NULL REFERENCES public.eventos (id) ON DELETE CASCADE,
  rol_evento  text NOT NULL DEFAULT 'vendedor'
                CHECK (rol_evento = ANY (ARRAY[
                  'admin_evento', 'vendedor', 'acreditador', 'visor', 'externo'
                ])),
  created_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (usuario_id, evento_id)
);

-- Módulo Capturador de leads (app hermana fusionada). Independiente de
-- public.eventos (registro/acreditación); leads.evento_id NUNCA apunta a eventos.
CREATE TABLE IF NOT EXISTS public.eventos_leads (
  id                          uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre                      text NOT NULL,
  pais                        text,
  fecha                       date NOT NULL,
  tematica                    text,
  certificacion_capacitacion  boolean DEFAULT false,
  perfil_id                   uuid,
  created_at                  timestamptz DEFAULT now(),
  CONSTRAINT eventos_leads_pkey PRIMARY KEY (id),
  CONSTRAINT eventos_leads_perfil_id_fkey FOREIGN KEY (perfil_id)
    REFERENCES public.perfiles (id)
);

CREATE TABLE IF NOT EXISTS public.leads (
  id              uuid NOT NULL DEFAULT gen_random_uuid(),
  evento_id       uuid NOT NULL,
  nombre_completo text NOT NULL,
  empresa         text,
  cargo           text,
  telefono        text,
  email           text,
  descripcion     text,
  fotos_urls      text[] NOT NULL DEFAULT '{}'::text[],
  perfil_id       uuid,
  created_at      timestamptz DEFAULT now(),
  CONSTRAINT leads_pkey PRIMARY KEY (id),
  CONSTRAINT leads_evento_id_fkey FOREIGN KEY (evento_id)
    REFERENCES public.eventos_leads (id),
  CONSTRAINT leads_perfil_id_fkey FOREIGN KEY (perfil_id)
    REFERENCES public.perfiles (id)
);

-- ----------------------------------------------------------------
-- 2. Índices
-- ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_registrados_evento_id     ON public.registrados (evento_id);
CREATE INDEX IF NOT EXISTS idx_registrados_email         ON public.registrados (email);
CREATE INDEX IF NOT EXISTS idx_registrados_acreditado     ON public.registrados (evento_id, acreditado);
CREATE INDEX IF NOT EXISTS idx_eventos_creado_por         ON public.eventos (creado_por);
CREATE INDEX IF NOT EXISTS idx_eventos_activo_fecha       ON public.eventos (activo, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_usuarios_eventos_evento_id ON public.usuarios_eventos (evento_id);
CREATE INDEX IF NOT EXISTS idx_eventos_leads_perfil_id ON public.eventos_leads (perfil_id);
CREATE INDEX IF NOT EXISTS idx_leads_evento_id ON public.leads (evento_id);
CREATE INDEX IF NOT EXISTS idx_leads_perfil_id ON public.leads (perfil_id);

-- ----------------------------------------------------------------
-- 3. Funciones helper
-- ----------------------------------------------------------------

-- SECURITY DEFINER + tabla calificada evita el problema clásico de RLS
-- recursiva (una policy de "perfiles" que hace SELECT sobre "perfiles").
CREATE OR REPLACE FUNCTION public.rpe_is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid() AND p.rol = 'admin' AND p.activo = true
  );
$$;

CREATE OR REPLACE FUNCTION public.rpe_is_organizador()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid() AND p.rol = 'organizador' AND p.activo = true
  );
$$;

CREATE OR REPLACE FUNCTION public.rpe_can_manage_users()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT public.rpe_is_admin();
$$;

CREATE OR REPLACE FUNCTION public.rpe_can_create_content()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT public.rpe_is_admin() OR public.rpe_is_organizador();
$$;

CREATE OR REPLACE FUNCTION public.rpe_is_externo()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid() AND p.rol = 'externo' AND p.activo = true
  );
$$;

CREATE OR REPLACE FUNCTION public.rpe_is_internal_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid()
      AND p.rol IN ('admin', 'organizador', 'user')
      AND p.activo = true
  );
$$;

-- Preferido/activo del externo (compat). El alcance RLS usa rpe_externo_tiene_evento.
CREATE OR REPLACE FUNCTION public.rpe_evento_asignado_externo()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT p.evento_asignado_id
  FROM public.perfiles p
  WHERE p.id = auth.uid() AND p.rol = 'externo' AND p.activo = true;
$$;

CREATE OR REPLACE FUNCTION public.rpe_externo_tiene_evento(p_evento_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.perfiles p
    JOIN public.usuarios_eventos ue
      ON ue.usuario_id = p.id
    WHERE p.id = auth.uid()
      AND p.rol = 'externo'
      AND p.activo = true
      AND ue.evento_id = p_evento_id
  );
$$;

-- Campaña (eventos_leads) homónima a un evento autorizado del externo.
CREATE OR REPLACE FUNCTION public.cl_externo_campana_autorizada(p_campana_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.eventos_leads el
    JOIN public.eventos e
      ON lower(trim(e.nombre)) = lower(trim(el.nombre))
    WHERE el.id = p_campana_id
      AND public.rpe_is_externo()
      AND (
        public.rpe_externo_tiene_evento(e.id)
        OR e.id = public.rpe_evento_asignado_externo()
      )
  );
$$;

-- Nombre de campaña coincide con evento autorizado (INSERT/SELECT).
CREATE OR REPLACE FUNCTION public.cl_externo_nombre_campana_autorizado(p_nombre text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.eventos e
    WHERE lower(trim(e.nombre)) = lower(trim(p_nombre))
      AND public.rpe_is_externo()
      AND (
        public.rpe_externo_tiene_evento(e.id)
        OR e.id = public.rpe_evento_asignado_externo()
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.rpe_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_perfiles_updated_at ON public.perfiles;
CREATE TRIGGER trg_perfiles_updated_at BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.rpe_set_updated_at();

DROP TRIGGER IF EXISTS trg_eventos_updated_at ON public.eventos;
CREATE TRIGGER trg_eventos_updated_at BEFORE UPDATE ON public.eventos
  FOR EACH ROW EXECUTE FUNCTION public.rpe_set_updated_at();

DROP TRIGGER IF EXISTS trg_registrados_updated_at ON public.registrados;
CREATE TRIGGER trg_registrados_updated_at BEFORE UPDATE ON public.registrados
  FOR EACH ROW EXECUTE FUNCTION public.rpe_set_updated_at();

-- --- CORRECCIÓN CRÍTICA (doc Sección 8.2/17.6): anti-escalación de rol ---
-- RLS por sí sola no puede comparar OLD vs NEW en un UPDATE (WITH CHECK solo
-- ve la fila nueva). Por eso la regla de negocio "nadie puede cambiar su
-- propio rol salvo un admin" se implementa acá, en un trigger, que sí tiene
-- acceso a OLD y NEW.
CREATE OR REPLACE FUNCTION public.rpe_prevent_role_self_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.rol IS DISTINCT FROM OLD.rol AND NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede cambiar el rol de un usuario';
  END IF;

  IF NEW.activo IS DISTINCT FROM OLD.activo AND NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede activar/desactivar un usuario';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_perfiles_prevent_role_escalation ON public.perfiles;
CREATE TRIGGER trg_perfiles_prevent_role_escalation
  BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.rpe_prevent_role_self_escalation();

CREATE OR REPLACE FUNCTION public.rpe_validate_perfil_externo()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.rol = 'externo' AND NEW.evento_asignado_id IS NULL THEN
    RAISE EXCEPTION 'Un usuario externo debe tener evento_asignado_id';
  END IF;
  IF NEW.rol <> 'externo' AND NEW.evento_asignado_id IS NOT NULL THEN
    NEW.evento_asignado_id := NULL;
  END IF;
  IF TG_OP = 'UPDATE'
     AND NEW.rol = 'externo'
     AND NEW.evento_asignado_id IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM public.usuarios_eventos ue WHERE ue.usuario_id = NEW.id
     )
     AND NOT EXISTS (
       SELECT 1
       FROM public.usuarios_eventos ue
       WHERE ue.usuario_id = NEW.id
         AND ue.evento_id = NEW.evento_asignado_id
     ) THEN
    RAISE EXCEPTION 'El evento activo debe estar entre los autorizados del usuario';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_perfiles_validate_externo ON public.perfiles;
CREATE TRIGGER trg_perfiles_validate_externo
  BEFORE INSERT OR UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.rpe_validate_perfil_externo();

-- Crea automáticamente el perfil al confirmarse un nuevo usuario en auth.users,
-- evitando el flujo manual/edge-case de "usuario ofuscado" documentado en
-- authService.ts (doc Sección 3.8). El rol por defecto es el más bajo posible.
CREATE OR REPLACE FUNCTION public.rpe_handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rol text := COALESCE(NEW.raw_user_meta_data ->> 'rol', 'user');
  v_evento_id uuid := NULL;
BEGIN
  IF v_rol = 'externo' THEN
    v_evento_id := NULLIF(NEW.raw_user_meta_data ->> 'evento_id', '')::uuid;
  ELSE
    v_rol := 'user';
  END IF;

  IF v_rol NOT IN ('admin', 'organizador', 'user', 'externo') THEN
    v_rol := 'user';
  END IF;

  INSERT INTO public.perfiles (id, nombre_completo, rol, evento_asignado_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'nombre_completo', split_part(NEW.email, '@', 1)),
    v_rol,
    v_evento_id
  )
  ON CONFLICT (id) DO NOTHING;

  IF v_rol = 'externo' AND v_evento_id IS NOT NULL THEN
    INSERT INTO public.usuarios_eventos (usuario_id, evento_id, rol_evento)
    VALUES (NEW.id, v_evento_id, 'externo')
    ON CONFLICT (usuario_id, evento_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.rpe_handle_new_user();

-- ----------------------------------------------------------------
-- 4. RPCs usadas por la app (equivalentes a las del proyecto legado)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marcar_recuperacion_pass(email_input text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.perfiles
  SET cambiar_pass = true
  WHERE id = (SELECT id FROM auth.users WHERE email = email_input);
END;
$$;

CREATE OR REPLACE FUNCTION public.verificar_usuario_registrado(email_check text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM auth.users WHERE email = email_check);
$$;

-- Lookup de auth.users por email para Edge Functions (service role).
-- La usa `reset-password` (vía _shared/find_user.ts) porque
-- auth.admin.listUsers() falla en este proyecto con "Database error finding
-- users". Solo service_role puede ejecutarla (no expuesta a authenticated/anon).
CREATE OR REPLACE FUNCTION public.rpe_auth_user_id_por_email(email_input text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
STABLE
AS $$
  SELECT u.id
  FROM auth.users u
  WHERE lower(u.email) = lower(trim(email_input))
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.rpe_auth_user_id_por_email(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpe_auth_user_id_por_email(text) TO service_role;

-- Admin: email de auth.users para formularios de gestión.
CREATE OR REPLACE FUNCTION public.rpe_obtener_email_usuario(usuario_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede consultar emails de usuarios';
  END IF;

  RETURN (
    SELECT u.email
    FROM auth.users u
    WHERE u.id = usuario_id
  );
END;
$$;

-- Permite a un admin cambiar el rol de otro usuario sin exponer un UPDATE
-- directo de la columna `rol` desde el cliente (defensa en profundidad,
-- además del trigger de la sección 3).
CREATE OR REPLACE FUNCTION public.rpe_actualizar_rol_usuario(usuario_id uuid, nuevo_rol text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede cambiar roles';
  END IF;

  IF nuevo_rol NOT IN ('admin', 'organizador', 'user') THEN
    RAISE EXCEPTION 'Rol inválido: %', nuevo_rol;
  END IF;

  DELETE FROM public.usuarios_eventos WHERE usuario_id = rpe_actualizar_rol_usuario.usuario_id;

  UPDATE public.perfiles
  SET rol = nuevo_rol,
      evento_asignado_id = NULL
  WHERE id = rpe_actualizar_rol_usuario.usuario_id;
END;
$$;

-- Admin: reemplaza el set de eventos autorizados de un externo.
CREATE OR REPLACE FUNCTION public.rpe_sincronizar_eventos_externo(
  p_usuario_id uuid,
  p_evento_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rol text;
  v_activo uuid;
  v_primero uuid;
BEGIN
  IF NOT public.rpe_is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede sincronizar eventos de externos';
  END IF;

  IF p_evento_ids IS NULL OR cardinality(p_evento_ids) < 1 THEN
    RAISE EXCEPTION 'Debe seleccionar al menos un evento';
  END IF;

  SELECT rol INTO v_rol FROM public.perfiles WHERE id = p_usuario_id;
  IF v_rol IS NULL THEN
    RAISE EXCEPTION 'Usuario no encontrado';
  END IF;
  IF v_rol <> 'externo' THEN
    RAISE EXCEPTION 'Solo se pueden sincronizar eventos de usuarios externos';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_evento_ids) AS eid
    WHERE NOT EXISTS (SELECT 1 FROM public.eventos e WHERE e.id = eid)
  ) THEN
    RAISE EXCEPTION 'Uno o más eventos no existen';
  END IF;

  DELETE FROM public.usuarios_eventos
  WHERE usuario_id = p_usuario_id
    AND evento_id <> ALL (p_evento_ids);

  INSERT INTO public.usuarios_eventos (usuario_id, evento_id, rol_evento)
  SELECT p_usuario_id, eid, 'externo'
  FROM unnest(p_evento_ids) AS eid
  ON CONFLICT (usuario_id, evento_id) DO UPDATE
    SET rol_evento = 'externo';

  SELECT evento_asignado_id INTO v_activo
  FROM public.perfiles
  WHERE id = p_usuario_id;

  v_primero := p_evento_ids[1];

  IF v_activo IS NULL OR v_activo <> ALL (p_evento_ids) THEN
    UPDATE public.perfiles
    SET evento_asignado_id = v_primero
    WHERE id = p_usuario_id;
  END IF;
END;
$$;

-- Perfil sistema al que se reasignan las acreditaciones cuando se
-- elimina al usuario que las hizo. UUID fijo; no aparece en la UI
-- de gestión (activo=false). Ver RPC rpe_eliminar_usuario más abajo.
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, is_super_admin, is_sso_user, is_anonymous,
  banned_until, confirmation_token, recovery_token,
  email_change_token_new, email_change
)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated', 'authenticated',
  'sistema.usuario.eliminado@internal.local',
  crypt(gen_random_uuid()::text, gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"nombre_completo":"Usuario eliminado"}'::jsonb,
  now(), now(), false, false, false, 'infinity'::timestamptz,
  '', '', '', ''
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.perfiles (id, nombre_completo, rol, activo, cambiar_pass)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Usuario eliminado', 'user', false, false
)
ON CONFLICT (id) DO NOTHING;

-- Evita el RAISE del trigger anti-escalación al fijar activo=false
-- desde el SQL Editor (sin JWT de admin).
ALTER TABLE public.perfiles
  DISABLE TRIGGER trg_perfiles_prevent_role_escalation;
UPDATE public.perfiles
SET nombre_completo = 'Usuario eliminado', activo = false, cambiar_pass = false, rol = 'user'
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
ALTER TABLE public.perfiles
  ENABLE TRIGGER trg_perfiles_prevent_role_escalation;

-- Elimina por completo la cuenta de un usuario. Debe ser un RPC
-- SECURITY DEFINER porque el cliente (anon key) no tiene permisos sobre
-- auth.users.
--
-- Regla de negocio: todas las FKs históricas (acreditado_por,
-- ingresado_por, creado_por, leads.perfil_id, eventos_leads.perfil_id)
-- se reasignan al perfil sistema "Usuario eliminado" (uuid fijo). No
-- deben quedar NULL. Si otra tabla ajena bloquea el DELETE de
-- auth.users, se degrada a ban permanente ('desactivado').
--
-- Devuelve 'eliminado' o 'desactivado' según el resultado.
DROP FUNCTION IF EXISTS public.rpe_eliminar_usuario(uuid);
CREATE FUNCTION public.rpe_eliminar_usuario(usuario_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sentinel constant uuid := '00000000-0000-0000-0000-000000000001';
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

  -- Reasignar historial al perfil "Usuario eliminado" (sin NULL).
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
      WHERE ue.usuario_id = rpe_eliminar_usuario.usuario_id;
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

-- Permisos para que la app (rol authenticated) pueda invocar RPCs vía PostgREST.
-- Sin estos GRANT, signUp/login funcionan pero las llamadas .rpc() fallan con
-- "permission denied for function ...".
GRANT EXECUTE ON FUNCTION public.marcar_recuperacion_pass(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verificar_usuario_registrado(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpe_actualizar_rol_usuario(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpe_eliminar_usuario(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpe_obtener_email_usuario(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpe_sincronizar_eventos_externo(uuid, uuid[]) TO authenticated;

-- ----------------------------------------------------------------
-- 5. RLS
-- ----------------------------------------------------------------
ALTER TABLE public.perfiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registrados      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos_leads    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads            ENABLE ROW LEVEL SECURITY;

-- --- perfiles ---
DROP POLICY IF EXISTS rpe_perfiles_select ON public.perfiles;
CREATE POLICY rpe_perfiles_select ON public.perfiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.rpe_can_manage_users());

DROP POLICY IF EXISTS rpe_perfiles_insert_own ON public.perfiles;
CREATE POLICY rpe_perfiles_insert_own ON public.perfiles
  FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

-- La escalación de privilegios (rol/activo) queda bloqueada por el trigger
-- rpe_prevent_role_self_escalation, no por esta policy. Esta policy solo
-- decide QUÉ FILA se puede tocar (propia, o cualquiera si eres admin).
DROP POLICY IF EXISTS rpe_perfiles_update ON public.perfiles;
CREATE POLICY rpe_perfiles_update ON public.perfiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid() OR public.rpe_is_admin())
  WITH CHECK (id = auth.uid() OR public.rpe_is_admin());

-- --- eventos: internos ven todo; externo solo eventos autorizados (usuarios_eventos).
DROP POLICY IF EXISTS rpe_eventos_all ON public.eventos;
DROP POLICY IF EXISTS rpe_eventos_select ON public.eventos;
CREATE POLICY rpe_eventos_select ON public.eventos
  FOR SELECT TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR public.rpe_externo_tiene_evento(id)
  );

DROP POLICY IF EXISTS rpe_eventos_insert ON public.eventos;
CREATE POLICY rpe_eventos_insert ON public.eventos
  FOR INSERT TO authenticated
  WITH CHECK (public.rpe_can_create_content());

DROP POLICY IF EXISTS rpe_eventos_update ON public.eventos;
CREATE POLICY rpe_eventos_update ON public.eventos
  FOR UPDATE TO authenticated
  USING (public.rpe_can_create_content())
  WITH CHECK (public.rpe_can_create_content());

DROP POLICY IF EXISTS rpe_eventos_delete ON public.eventos;
CREATE POLICY rpe_eventos_delete ON public.eventos
  FOR DELETE TO authenticated
  USING (public.rpe_is_admin());

-- Lectura pública mínima para que el formulario de autoregistro (anon)
-- pueda validar que el evento existe y está activo antes de insertar.
DROP POLICY IF EXISTS rpe_eventos_select_publico ON public.eventos;
CREATE POLICY rpe_eventos_select_publico ON public.eventos
  FOR SELECT TO anon USING (activo = true);

-- --- registrados: internos todos; externo solo eventos autorizados.
DROP POLICY IF EXISTS rpe_registrados_all ON public.registrados;
DROP POLICY IF EXISTS rpe_registrados_select ON public.registrados;
CREATE POLICY rpe_registrados_select ON public.registrados
  FOR SELECT TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR public.rpe_externo_tiene_evento(evento_id)
  );

DROP POLICY IF EXISTS rpe_registrados_insert ON public.registrados;
CREATE POLICY rpe_registrados_insert ON public.registrados
  FOR INSERT TO authenticated
  WITH CHECK (
    public.rpe_is_internal_user()
    OR public.rpe_externo_tiene_evento(evento_id)
  );

DROP POLICY IF EXISTS rpe_registrados_update ON public.registrados;
CREATE POLICY rpe_registrados_update ON public.registrados
  FOR UPDATE TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR public.rpe_externo_tiene_evento(evento_id)
  )
  WITH CHECK (
    public.rpe_is_internal_user()
    OR public.rpe_externo_tiene_evento(evento_id)
  );

DROP POLICY IF EXISTS rpe_registrados_delete ON public.registrados;
CREATE POLICY rpe_registrados_delete ON public.registrados
  FOR DELETE TO authenticated
  USING (public.rpe_is_admin());

-- Autoregistro público (reemplaza al formulario externo "Transworld" fuera
-- del repo, doc Sección 17.5): un visitante anónimo puede INSERTAR su propio
-- registro solo si el evento está activo, y solo con origen='publico'.
-- No puede leer, actualizar ni eliminar registros de nadie.
DROP POLICY IF EXISTS rpe_registrados_insert_publico ON public.registrados;
CREATE POLICY rpe_registrados_insert_publico ON public.registrados
  FOR INSERT TO anon
  WITH CHECK (
    origen = 'publico'
    AND acreditado = false
    AND ingresado_por IS NULL
    AND EXISTS (SELECT 1 FROM public.eventos e WHERE e.id = evento_id AND e.activo = true)
  );

-- --- usuarios_eventos ---
DROP POLICY IF EXISTS rpe_usuarios_eventos_select ON public.usuarios_eventos;
CREATE POLICY rpe_usuarios_eventos_select ON public.usuarios_eventos
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rpe_usuarios_eventos_write ON public.usuarios_eventos;
CREATE POLICY rpe_usuarios_eventos_write ON public.usuarios_eventos
  FOR ALL TO authenticated
  USING (public.rpe_is_admin())
  WITH CHECK (public.rpe_is_admin());

-- --- eventos_leads / leads (módulo Capturador; prefijo cl_ para no chocar
-- con las políticas rpe_ del módulo de registro) ---
DROP POLICY IF EXISTS cl_eventos_leads_select ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_select ON public.eventos_leads
  FOR SELECT TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR public.cl_externo_nombre_campana_autorizado(nombre)
  );

-- INSERT: internos siempre; externo solo campañas homónimas a eventos autorizados.
-- Crear/editar desde la UI sigue gated por canCreateContent en Flutter;
-- UPDATE requiere rpe_can_create_content(); DELETE requiere rpe_is_admin().
DROP POLICY IF EXISTS cl_eventos_leads_insert ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_insert ON public.eventos_leads
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      public.rpe_is_internal_user()
      OR public.cl_externo_nombre_campana_autorizado(nombre)
    )
    AND (perfil_id IS NULL OR perfil_id = auth.uid())
  );

DROP POLICY IF EXISTS cl_eventos_leads_update ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_update ON public.eventos_leads
  FOR UPDATE TO authenticated
  USING (public.rpe_can_create_content())
  WITH CHECK (public.rpe_can_create_content());

DROP POLICY IF EXISTS cl_eventos_leads_delete ON public.eventos_leads;
CREATE POLICY cl_eventos_leads_delete ON public.eventos_leads
  FOR DELETE TO authenticated
  USING (public.rpe_is_admin());

DROP POLICY IF EXISTS cl_leads_select ON public.leads;
CREATE POLICY cl_leads_select ON public.leads
  FOR SELECT TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR (public.rpe_is_externo() AND perfil_id = auth.uid())
  );

DROP POLICY IF EXISTS cl_leads_insert ON public.leads;
CREATE POLICY cl_leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (
    (perfil_id IS NULL OR perfil_id = auth.uid())
    AND (
      public.rpe_is_internal_user()
      OR public.cl_externo_campana_autorizada(evento_id)
    )
  );

DROP POLICY IF EXISTS cl_leads_update ON public.leads;
CREATE POLICY cl_leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (
    public.rpe_is_internal_user()
    OR (public.rpe_is_externo() AND perfil_id = auth.uid())
  )
  WITH CHECK (
    public.rpe_is_internal_user()
    OR (public.rpe_is_externo() AND perfil_id = auth.uid())
  );

DROP POLICY IF EXISTS cl_leads_delete ON public.leads;
CREATE POLICY cl_leads_delete ON public.leads
  FOR DELETE TO authenticated
  USING (public.rpe_is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.eventos_leads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.leads TO authenticated;

-- ----------------------------------------------------------------
-- 6. Storage buckets (ejecutar una vez; el dashboard de Supabase también
--    permite crearlos manualmente). Se listan acá para que quede
--    versionado junto con sus políticas.
-- ----------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('imagenes', 'imagenes', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('plantillas', 'plantillas', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS rpe_storage_imagenes_read ON storage.objects;
CREATE POLICY rpe_storage_imagenes_read ON storage.objects
  FOR SELECT USING (bucket_id = 'imagenes');

DROP POLICY IF EXISTS rpe_storage_imagenes_write ON storage.objects;
CREATE POLICY rpe_storage_imagenes_write ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'imagenes');

DROP POLICY IF EXISTS rpe_storage_imagenes_update ON storage.objects;
CREATE POLICY rpe_storage_imagenes_update ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'imagenes');

DROP POLICY IF EXISTS rpe_storage_plantillas_read ON storage.objects;
CREATE POLICY rpe_storage_plantillas_read ON storage.objects
  FOR SELECT USING (bucket_id = 'plantillas');

-- storage.prefixes: las versiones nuevas de Storage guardan acá una fila por
-- carpeta del path, con RLS propio. La app sube SIEMPRE dentro de una carpeta
-- (`imagenes/eventos/...`, `imagenes/leads/...`), así que sin estas políticas
-- toda subida falla con "new row violates row-level security policy" aunque
-- las de storage.objects estén bien — cuesta de diagnosticar porque el error
-- señala a objects.
--
-- Va dentro de un DO porque la tabla no existe en instalaciones de Storage
-- anteriores, y ahí este bloque simplemente no hace nada.
DO $$
BEGIN
  IF to_regclass('storage.prefixes') IS NULL THEN
    RAISE NOTICE 'storage.prefixes no existe: no hace falta crear políticas.';
    RETURN;
  END IF;

  DROP POLICY IF EXISTS rpe_storage_prefixes_read ON storage.prefixes;
  CREATE POLICY rpe_storage_prefixes_read ON storage.prefixes
    FOR SELECT USING (bucket_id IN ('imagenes', 'plantillas'));

  DROP POLICY IF EXISTS rpe_storage_prefixes_write ON storage.prefixes;
  CREATE POLICY rpe_storage_prefixes_write ON storage.prefixes
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'imagenes');

  DROP POLICY IF EXISTS rpe_storage_prefixes_update ON storage.prefixes;
  CREATE POLICY rpe_storage_prefixes_update ON storage.prefixes
    FOR UPDATE TO authenticated USING (bucket_id = 'imagenes');
END $$;
