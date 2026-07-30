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
    updates/      # OTA vía GitHub Releases (Android)
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
- Las Edge Functions de correo viven en `supabase/functions/`:
  - `crear-usuario` — alta de usuario por admin + email de credenciales
  - `regenerar-password-usuario` — nueva password por admin + email
  - `reset-password` — olvido de contraseña: autogenera y envía por email
  - `enviar-qr` — QR de acreditación (ya desplegada; usa Brevo)
  El envío de credenciales reutiliza el secret existente `BREVO_API_KEY`
  (mismo mailer que `enviar-qr` / `reset-password`).
  Desplegar con `supabase functions deploy`. Para `reset-password` usar
  `--no-verify-jwt` (se invoca sin sesión). El esquema completo (tablas,
  RLS, RPCs) vive en `supabase/schema.sql`.

## Actualizaciones OTA (Android / Windows / GitHub Releases)

Nexus se distribuye de forma privada vía **GitHub Releases** (sin Play Store
ni Supabase Storage). En **Android** y **Windows**, tras el login la app consulta:

`GET https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/releases/latest`

y ofrece instalar la actualización si el `tag_name` (SemVer) es mayor que la
versión instalada (`package_info_plus` ↔ `pubspec.yaml`).

### Convención de Release

| Elemento | Contrato |
|----------|----------|
| Tag | `vMAJOR.MINOR.PATCH` (ej. `v1.2.0`) |
| `pubspec.yaml` | `version: MAJOR.MINOR.PATCH+BUILD` **debe coincidir** con el tag (sin `v`) |
| Asset Android | `android-NEXUS-vMAJOR.MINOR.PATCH.apk` |
| Asset Windows | `windows-NEXUS-vMAJOR.MINOR.PATCH.zip` (contenido de `build/windows/x64/runner/Release/`) |
| Force update | Incluir la línea `[FORCE_UPDATE]` en el body de la Release |

Si el body contiene `[FORCE_UPDATE]`, el diálogo no se puede cerrar ni
posponer hasta instalar.

### Cómo se aplica la actualización

| | Android | Windows |
|---|---|---|
| Asset | `.apk` | `.zip` |
| Mecanismo | Instalador del sistema (`OpenFilex` + permiso *instalar apps desconocidas*) | Script PowerShell *out-of-process* que reemplaza la carpeta de instalación |
| Reinicio | Manual (lo hace el instalador) | Automático (el script relanza Nexus) |

En **Windows** el flujo es: descarga → verificación SHA-256 → la app lanza un
actualizador desacoplado y se cierra (`exit(0)`) → el actualizador espera a que
el proceso libere el `.exe`, extrae el ZIP sobre la carpeta de instalación y
vuelve a abrir Nexus.

Garantías del actualizador (`lib/features/updates/services/windows_installer.dart`):

- **Pre-flight de escritura**: si la carpeta de instalación no es escribible, la
  app **no se cierra** y muestra el error. Nexus debe vivir en una carpeta de
  usuario (ej. `%LOCALAPPDATA%\Nexus`); en `C:\Program Files` haría falta
  elevación y la OTA no se aplicará.
- **Validación del paquete**: si el ZIP no contiene el `.exe`, se aborta sin
  tocar la instalación.
- **Backup + rollback**: se respalda la instalación antes de sobrescribir y se
  restaura si la copia falla.
- **Reintentos**: la copia reintenta ante archivos bloqueados (antivirus,
  indexador) antes de darse por vencida.
- **Nunca deja al usuario sin app**: pase lo que pase, se relanza Nexus.
- **Traza**: cada intento queda registrado en `%TEMP%\nexus-update.log`.

Los archivos ajenos al paquete (config local del usuario) se conservan: la
actualización copia encima, no borra la carpeta.

### Instalador bootstrap (Windows — primera instalación)

En lugar de un `.exe` grande por versión, Nexus usa un **instalador ligero**
que consulta GitHub Releases en runtime e instala siempre la última versión.

| Archivo | Uso |
|---------|-----|
| `scripts/install-nexus.ps1` | Script principal (API → descarga ZIP → extrae) |
| `scripts/install-nexus.bat` | Launcher de doble clic |
| `scripts/uninstall-nexus.ps1` | Desinstalación (binarios, datos en `%APPDATA%`, accesos directos) |
| `installer_script.iss` | Wrapper Inno Setup → genera `NexusSetup.exe` |

**Instalación rápida** (desde el repo clonado):

```powershell
.\scripts\install-nexus.bat
# o con acceso directo en el escritorio:
.\scripts\install-nexus.ps1 -DesktopShortcut
```

**Compilar `NexusSetup.exe`** (requiere [Inno Setup 6+](https://jrsoftware.org/isinfo.php)):

```powershell
.\scripts\build-installer.ps1
# Salida: build\windows\installer\NexusSetup.exe
```

Flujo del bootstrap:

1. `GET /repos/{owner}/{repo}/releases/latest`
2. Descarga `windows-NEXUS-vX.Y.Z.zip`
3. Verifica SHA-256 si GitHub expone `digest` en el asset
4. Extrae en `%LOCALAPPDATA%\Nexus` (compatible con OTA posterior)
5. Crea accesos en el menú Inicio (y escritorio si se pide)
6. Registra desinstalación en *Agregar o quitar programas* (salvo vía Inno Setup)

Traza de instalación: `%TEMP%\nexus-install.log`.

El bootstrap **no se recompila por release**; solo hay que volver a publicarlo
si cambia la lógica de instalación. Los binarios vienen siempre del ZIP en GitHub.

### Firma release (obligatoria para upgrades reales)

1. Genera un keystore (una sola vez) y guárdalo fuera de git.
2. Copia `android/key.properties.example` → `android/key.properties` y completa.
3. En CI, configura secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
   `KEY_PASSWORD`, `KEY_ALIAS`.

Sin keystore, Gradle firma con debug (útil en local; **no** para distribución).

### Publicar una versión

1. Sube `pubspec.yaml` (`version: X.Y.Z+N`) y haz merge a `main`.
2. Crea y pushea el tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. El workflow [`.github/workflows/release-android.yml`](.github/workflows/release-android.yml)
   valida que pubspec == tag, construye el APK y el ZIP de Windows, y crea/actualiza
   el Release con los assets `android-NEXUS-vX.Y.Z.apk` y `windows-NEXUS-vX.Y.Z.zip`.
4. (Opcional) Edita las notas del Release y agrega `[FORCE_UPDATE]` si aplica.

### Variables `.env`

Ver `.env.example`: `GITHUB_OWNER`, `GITHUB_REPO`, `UPDATE_CHANNEL`.
