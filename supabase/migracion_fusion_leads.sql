-- ============================================================
-- MIGRACIÓN: fusión de la app de Leads/Captura de clientes
-- dentro de la base de datos de Registro de Eventos (destino)
-- ============================================================
--
-- DECISIONES CONFIRMADAS (ver conversación):
-- 1. Ambas apps comparten el mismo proyecto Supabase / auth.users
--    => public.perfiles NO requiere cambios estructurales.
-- 2. Los eventos de ambas apps NO están relacionados entre sí
--    => se mantienen DOS tablas de eventos independientes:
--         public.eventos        (ya existente, app registro/acreditación)
--         public.eventos_leads  (nueva, app de leads/captura de clientes)
-- 3. Alcance: solo DDL. No se migran filas desde la BD de origen.
-- 4. RLS: habilitado en las tablas nuevas (prefijo cl_ para no chocar
--    con las políticas rpe_ de la app de registro/acreditación).
--
-- Este script es ADITIVO: no modifica ni elimina nada de las
-- tablas ya existentes (perfiles, eventos, registrados).
-- ============================================================


-- ------------------------------------------------------------
-- 0. Pre-requisitos
-- ------------------------------------------------------------
-- gen_random_uuid() ya está disponible en el destino (lo usan
-- public.eventos y public.registrados), no se requiere habilitar
-- extensiones adicionales (pgcrypto/uuid-ossp).
--
-- ⚠ SEGURIDAD EN PRODUCCIÓN (leer antes de ejecutar):
--   * Este script es 100% ADITIVO: no contiene ALTER/DROP/UPDATE/
--     DELETE/TRUNCATE sobre ninguna tabla existente.
--   * Va envuelto en una única transacción (BEGIN/COMMIT): si algo
--     falla (p.ej. una tabla ya existe), se hace ROLLBACK completo
--     y NO queda nada a medio crear.
--   * lock_timeout evita que, si public.perfiles está ocupada, la
--     creación de las FKs se quede esperando y frene las escrituras
--     de la app en producción: falla rápido en vez de encolar.
--
-- VERIFICACIÓN PREVIA (opcional, ejecutar por separado ANTES):
--   Confirma que los nombres nuevos no colisionan con nada existente.
--   Debe devolver 0 filas:
--
--     SELECT table_name FROM information_schema.tables
--     WHERE table_schema = 'public'
--       AND table_name IN ('eventos_leads', 'leads');


-- ------------------------------------------------------------
-- INICIO DE TRANSACCIÓN (todo-o-nada)
-- ------------------------------------------------------------
BEGIN;

-- Si perfiles está bloqueada por otra operación, abortar en 3s en
-- lugar de esperar indefinidamente y bloquear la producción.
SET LOCAL lock_timeout = '3s';


-- ------------------------------------------------------------
-- 1. public.perfiles -> SIN CAMBIOS DE ESTRUCTURA
-- ------------------------------------------------------------
-- El CHECK vigente en el destino:
--   CHECK (rol = ANY (ARRAY['admin','vendedor','user']))
-- ya es superconjunto del CHECK de la app de leads
-- (ARRAY['admin','user']), por lo que no se requiere ALTER TABLE.
--
-- ⚠ PUNTO DE ATENCIÓN FUNCIONAL (verificar antes de poner en producción):
-- El DEFAULT de "rol" en el destino es 'vendedor'; en la app de
-- leads era 'user'. Si esa app crea perfiles mediante INSERT sin
-- especificar "rol" explícitamente (confiando en el DEFAULT de
-- columna), el comportamiento cambiará silenciosamente al pasar
-- a la base fusionada. Confirmar en el código de la app de leads
-- que "rol" siempre se envía de forma explícita.


-- ------------------------------------------------------------
-- 2. public.eventos_leads
--    (antes "eventos" en la app de leads; renombrada para no
--     colisionar con public.eventos, que pertenece a la otra app)
-- ------------------------------------------------------------
CREATE TABLE public.eventos_leads (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  pais text,
  fecha date NOT NULL,
  tematica text,
  certificacion_capacitacion boolean DEFAULT false,
  perfil_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT eventos_leads_pkey PRIMARY KEY (id),
  CONSTRAINT eventos_leads_perfil_id_fkey FOREIGN KEY (perfil_id)
    REFERENCES public.perfiles(id)
);

COMMENT ON TABLE public.eventos_leads IS
  'Eventos de la app de captura de leads/clientes. Tabla independiente de public.eventos (app de registro/acreditación); no existe relación entre ambas.';

-- Postgres no indexa automáticamente las columnas FK.
CREATE INDEX idx_eventos_leads_perfil_id ON public.eventos_leads (perfil_id);


-- ------------------------------------------------------------
-- 3. public.leads
-- ------------------------------------------------------------
CREATE TABLE public.leads (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  evento_id uuid NOT NULL,
  nombre_completo text NOT NULL,
  empresa text,
  cargo text,
  telefono text,
  email text,
  descripcion text,
  fotos_urls text[] NOT NULL DEFAULT '{}'::text[],
  perfil_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT leads_pkey PRIMARY KEY (id),
  CONSTRAINT leads_evento_id_fkey FOREIGN KEY (evento_id)
    REFERENCES public.eventos_leads (id),
  CONSTRAINT leads_perfil_id_fkey FOREIGN KEY (perfil_id)
    REFERENCES public.perfiles (id)
);

COMMENT ON TABLE public.leads IS
  'Leads/clientes capturados en eventos. evento_id referencia exclusivamente public.eventos_leads, nunca public.eventos.';

CREATE INDEX idx_leads_evento_id ON public.leads (evento_id);
CREATE INDEX idx_leads_perfil_id ON public.leads (perfil_id);


-- ------------------------------------------------------------
-- 4. Row Level Security (solo tablas nuevas)
-- ------------------------------------------------------------
-- Reutiliza public.rpe_is_admin() (ya definida en schema.sql del
-- proyecto de registro). No crea ni altera funciones existentes.
--
-- Modelo de acceso (app capturador-leads):
--   * Usuarios autenticados leen eventos/leads del equipo.
--   * Cada usuario escribe leads y eventos propios (perfil_id).
--   * Admin puede todo; anon no tiene acceso.
ALTER TABLE public.eventos_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

-- --- eventos_leads ---
CREATE POLICY cl_eventos_leads_select ON public.eventos_leads
  FOR SELECT TO authenticated USING (true);

CREATE POLICY cl_eventos_leads_insert ON public.eventos_leads
  FOR INSERT TO authenticated
  WITH CHECK (perfil_id IS NULL OR perfil_id = auth.uid());

CREATE POLICY cl_eventos_leads_update ON public.eventos_leads
  FOR UPDATE TO authenticated
  USING (perfil_id = auth.uid() OR public.rpe_is_admin())
  WITH CHECK (perfil_id = auth.uid() OR public.rpe_is_admin());

CREATE POLICY cl_eventos_leads_delete ON public.eventos_leads
  FOR DELETE TO authenticated
  USING (perfil_id = auth.uid() OR public.rpe_is_admin());

-- --- leads ---
CREATE POLICY cl_leads_select ON public.leads
  FOR SELECT TO authenticated USING (true);

CREATE POLICY cl_leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (perfil_id IS NULL OR perfil_id = auth.uid());

CREATE POLICY cl_leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (perfil_id = auth.uid() OR public.rpe_is_admin())
  WITH CHECK (perfil_id = auth.uid() OR public.rpe_is_admin());

CREATE POLICY cl_leads_delete ON public.leads
  FOR DELETE TO authenticated
  USING (public.rpe_is_admin());


-- ------------------------------------------------------------
-- FIN DE TRANSACCIÓN: si todo lo anterior corrió sin error, se
-- confirma; ante cualquier fallo, ROLLBACK deja la BD intacta.
-- ------------------------------------------------------------
COMMIT;


-- ------------------------------------------------------------
-- 5. Cambios requeridos en el código de la app de leads
--    (esto NO lo cubre este script; es trabajo de aplicación)
-- ------------------------------------------------------------
-- - Toda query/mutación que referencie la tabla "eventos" en esa
--   app debe apuntar ahora a "eventos_leads".
-- - La tabla "leads" y sus columnas (incluida "evento_id") NO
--   cambian de nombre: solo cambia la tabla a la que apunta la FK.
-- - Si la app usaba Supabase client con .from('eventos'), ese
--   nombre debe actualizarse a .from('eventos_leads').
