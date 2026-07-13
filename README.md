# Transworld Nexus (Flutter)

Reconstrucción en Flutter de **Registro Pro**, ahora bautizada **Transworld
Nexus**, unificando en un solo código
base lo que antes eran dos apps separadas e inconsistentes:
`registro-pro-eventos-master` (Expo/React Native) y `registro-pro-pc-main`
(React + Vite + Electron). Corre en Android, iOS, Web y escritorio
(macOS/Windows/Linux) desde el mismo código.

Este proyecto nace del levantamiento detallado documentado en
`documentacion_zips_registro_pro.md` (ver especialmente las Secciones 8, 17
y 18) y corrige explícitamente los hallazgos críticos ahí identificados.

## Qué se corrigió respecto al proyecto legado

| # | Problema en el proyecto legado | Corrección en este proyecto |
|---|---|---|
| 1 | **Escalación de privilegios**: la policy RLS `rpe_perfiles_update` no tenía `WITH CHECK`, cualquier usuario autenticado podía autoasignarse `rol = 'admin'` llamando directo a la API de Supabase. | `supabase/schema.sql` agrega el trigger `rpe_prevent_role_self_escalation`, que rechaza cualquier `UPDATE` que cambie `rol` o `activo` si quien lo ejecuta no es admin. Además, el cambio de rol desde la app pasa por el RPC `rpe_actualizar_rol_usuario` (`SECURITY DEFINER`), nunca por un `UPDATE` directo. |
| 2 | **Cola offline móvil rota**: `lib/offlineManager.ts` usaba la clave `capturador_leads_cola_offline` (nunca escrita), mientras las pantallas escribían en `registro_pro_cola_offline` (nunca leída). Los registros offline nunca se sincronizaban. | Una única cola (`data/offline/sync_queue_service.dart`), una única clave de `SharedPreferences`, con estado/reintentos/errores por ítem, y un único `SyncCoordinator` que dispara la sincronización al recuperar conexión. |
| 3 | `eventos` y `registrados` con RLS `USING (true) WITH CHECK (true)` para cualquier autenticado: la única barrera era ocultar botones en la UI. | Políticas separadas por operación: cualquier autenticado puede leer/registrar, pero crear/editar/eliminar eventos y eliminar registrados requiere `rol = 'admin'` **a nivel de base de datos**. |
| 4 | Sin constraint de duplicados en `registrados`: la deduplicación era solo a nivel de aplicación. | `UNIQUE (evento_id, email)` en la base de datos, reforzado (no reemplazado) por un chequeo previo en el cliente. |
| 5 | Esquema inconsistente: código y `.env` apuntaban a `registro_eventos`, pero `schema.sql` creaba todo en `public`. | Todo vive explícitamente en `public`, sin variables de esquema configurables que puedan desalinearse. |
| 6 | Base de datos compartida con la app hermana "capturador-leads" sin documentar el impacto. | Se mantiene compatible (mismo `auth.users`, trigger `rpe_handle_new_user` para altas), pero todas las políticas/funciones usan el prefijo `rpe_` para evitar colisiones, y queda documentado en `supabase/schema.sql`. |
| 7 | Formulario público de autoregistro vivía **fuera** de ambos repositorios (`intranet-transworld-dc.onrender.com`), como dependencia oculta e indocumentada. | El autoregistro público vive dentro de esta misma app (`/r/:eventoId`, sin sesión, rol `anon`), con su propia política RLS acotada (`rpe_registrados_insert_publico`). |
| 8 | Integración con Electron oculta (`window.ipcRenderer`) sin las herramientas de build correspondientes en el ZIP. | Ya no aplica: el mismo Flutter Desktop nativo cubre exportación de archivos sin depender de un runtime externo. |
| 9 | `.env` con credenciales reales incluido en el ZIP pese a `.gitignore`. | `.env` real nunca se versiona; `.env.example` documenta las variables sin valores reales. Ver `.gitignore`. |
| 10 | Control de acceso por rol solo en la UI (`if (rol === 'admin')` repetido en decenas de archivos). | Sigue existiendo en la UI por UX (`RequireAdmin`, `isAdminProvider`), pero ya no es la única barrera: RLS + triggers son la fuente de verdad. |
| 11 | El cambio obligatorio de contraseña (`perfiles.cambiar_pass`, regla 6.1 de la doc) existía como pantalla pero nada lo forzaba: un usuario marcado podía seguir usando la app. | El `redirect` del router fuerza `/recrear-pass` mientras `cambiar_pass = true`; al guardar la nueva contraseña se refresca el perfil y se vuelve al home. |
| 12 | La Edge Function `enviar-qr` estaba declarada pero **nunca se invocaba**, `email_confirmacion_enviado` nunca se marcaba, y ningún flujo mostraba/entregaba el QR del asistente (la pantalla de escaneo leía un QR que nadie tenía). | Desde "Ver registrados" se puede abrir el QR de cada asistente (codifica `registrados.id`, lo mismo que lee el escáner) y enviarlo por email vía `enviar-qr`, marcando `email_confirmacion_enviado`. |

## Arquitectura

```
lib/
  core/           # Config, tema, router, constantes, widgets compartidos
  data/
    models/       # Entidades inmutables (Perfil, Evento, Registrado)
    repositories/ # Un repositorio por tabla/dominio, hablan con Supabase
    offline/      # Motor de sincronización offline unificado
    supabase/     # Inicialización y provider del cliente Supabase
  features/       # Un folder por pantalla/flujo de negocio
    auth/
    home/
    eventos/
    usar_app/
    registro/
    registro_publico/
    acreditacion/
    registrados/
    kpi/
    exportacion/
    usuarios/
```

- **Sistema de diseño**: `core/theme/app_theme.dart` define los tokens
  (colores semánticos, espaciado, radios) y el tema Material 3 completo,
  con navegación de línea iOS: transiciones Cupertino (swipe back) en
  todas las plataformas y **sin AppBars de Material** —
  `core/widgets/app_scaffold.dart` integra el título en el contenido con
  una flecha de volver a la izquierda, más el banner offline y el ancho
  máximo de contenido para Web/escritorio. Las pantallas no usan colores
  ni paddings "sueltos": consumen los tokens. En el home, el perfil del
  usuario vive integrado en un encabezado a sangre completa con un menú
  de cuenta colapsable (Mi perfil / Configuraciones / Cerrar sesión).
- **Flujo de autenticación**: el login está descompuesto en componentes
  (`features/auth/widgets/login/`: header hero dibujado con CustomPaint,
  formulario, botón con estados y animación de presión, tokens propios en
  `login_theme.dart`). Incluye "Recordarme" (persiste el correo en
  `SharedPreferences`), animaciones de entrada escalonadas (easeOutCubic,
  250–350 ms), colapso del hero al abrir el teclado, layout de dos paneles
  en pantallas ≥900 px y autoregistro de cuenta en `/registro` (el perfil
  lo crea el trigger `rpe_handle_new_user` con rol `user`).
- **Gestión de estado**: Riverpod (`flutter_riverpod` 2.x), con providers
  simples (`Provider`, `FutureProvider`, `StateNotifierProvider`) — sin
  generación de código, para mantener el build simple y predecible.
- **Navegación**: `go_router`, con `redirect` reactivo a los cambios de
  sesión de Supabase (`GoRouterRefreshStream`).
- **Persistencia offline**: `shared_preferences` como almacenamiento del
  motor de sincronización (`SyncQueueService`), que funciona igual en
  Android, iOS, Web y escritorio.
- **Backend**: Supabase (Postgres + Auth + Storage), esquema `public`. Ver
  `supabase/schema.sql` para el modelo completo, políticas RLS, triggers y
  funciones RPC.

## Cómo correr el proyecto

1. Instala las dependencias:

   ```bash
   flutter pub get
   ```

2. Copia `.env.example` a `.env` y completa con los datos de tu proyecto
   Supabase:

   ```bash
   cp .env.example .env
   ```

3. Aplica `supabase/schema.sql` en tu proyecto Supabase (SQL Editor o
   `supabase db push` si usas el CLI). Es idempotente: puede ejecutarse
   varias veces sin duplicar objetos.

4. Corre la app:

   ```bash
   flutter run                # dispositivo/emulador conectado
   flutter run -d chrome      # Web
   flutter run -d macos       # macOS (requiere Xcode)
   ```

## Verificación realizada

- `flutter analyze` → sin advertencias ni errores.
- `flutter test` → pasa (ver `test/widget_test.dart`; las pruebas de pantallas
  reales deberían mockear los repositorios de `data/repositories/`).
- `flutter build web --release` → build exitoso.
- Para build de macOS/iOS/Android nativo hace falta un entorno con
  Xcode/Android SDK completos (fuera del sandbox de desarrollo usado para
  crear este proyecto); el código Dart ya está validado por `analyze` +
  `build web`.

## Pendiente / próximos pasos

- **Integración con "capturador-leads"**: el esquema ya es compatible
  (mismo `auth.users`, mismo esquema `public`, prefijo `rpe_` para evitar
  colisiones de nombres), pero todavía no se implementó ninguna pantalla
  que consuma datos de esa app hermana. Cuando se defina el alcance exacto
  de esa integración, agregar los repositorios/pantallas correspondientes
  siguiendo el mismo patrón (`data/repositories/`, `features/<dominio>/`).
- Tabla `usuarios_eventos` ya está creada en el schema (para asignar
  vendedores/acreditadores a eventos específicos) pero **no se usa aún**
  para restringir acceso: hoy cualquier usuario autenticado puede operar
  cualquier evento. Es la base para una futura mejora de RLS más granular.
- Tests de integración con mocks de Supabase (por ejemplo con
  `mocktail` + fakes de `SupabaseClient`) para los repositorios y el motor
  de sincronización offline.
- Configurar íconos/splash screen definitivos (`flutter_launcher_icons`,
  `flutter_native_splash`) — hoy el proyecto usa los assets por defecto de
  `flutter create`.
- Subir `Plantilla_Registro.xlsx` al bucket `plantillas` de Storage (lo
  referencia `StorageRepository.urlPlantillaRegistro`, pero el archivo en
  sí no se genera desde este repo).
- Las Edge Functions `reset-password` y `enviar-qr` se invocan desde la app
  (recuperación de contraseña y envío de QR por email) pero su código Deno
  no vive en este repo: deben desplegarse en el proyecto Supabase
  (`supabase functions deploy`). Mientras no existan, esos dos botones
  fallarán con un error controlado; el resto de la app no depende de ellas.
