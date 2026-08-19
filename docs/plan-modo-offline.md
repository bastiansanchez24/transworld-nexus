# Plan: modo offline (iOS/Android) y bloqueo en escritorio/web

Documento de producto y implementación. Cierra el diseño acordado para que
RegisPro sea usable en feria sin red en el teléfono, y se bloquee con aviso
a pantalla completa en Windows, Mac y web.

No incluye el formulario público de autoregistro (`/r/:eventoId`): es un
proyecto aparte y no se toca.

---

## 1. Problema

Hoy la app es híbrida: **escribe** sin red (cola de leads y registrados) pero
**no arranca ni navega** sin red. Los fallos reportados:

| # | Síntoma | Causa |
|---|---------|--------|
| 1 | Abrir sin internet → Login | Splash pide el perfil a la red. Si falla o pasan 8 s, el router hace `signOut()` |
| 2 | Listas de eventos/leads vacías al recargar | Eventos, actividades, fijados y usuarios no tienen caché. El refresh invalida el provider y vuelve a pedir al servidor |
| 3 | No se puede entrar a un evento sin red | `eventoByIdProvider` es solo red |
| 4 | Aviso “Sin conexión” tapa la hora | `OfflineBanner` se pinta desde `y = 0`, sin padding del status bar |

Además: fotos solo en RAM (`Image.network`); el usuario externo se echa de
sesión si el evento “no es operable”; el escáner del externo entra al flujo
de acreditación.

---

## 2. Estado actual (qué no tirar)

| Pieza | Archivo | Rol |
|-------|---------|-----|
| Cola unificada | `lib/data/offline/sync_queue_service.dart` | Insert/update de leads y registrados, estados, reintentos |
| Coordinador | `lib/data/offline/sync_coordinator.dart` | Vacía la cola al recuperar red y al primer online |
| Caché de lectura | `lib/data/offline/offline_read_cache.dart` | JSON en SharedPreferences: **solo** leads y registrados por evento |
| Fotos de lead pendientes | `lib/data/offline/pending_photo_store*.dart` | Disco local (`local_foto://…`) en iOS/Android |
| Conectividad | `lib/core/network/connectivity_service.dart` | `connectivity_plus` (interfaz, no internet real) |
| Banner | `lib/core/widgets/offline_banner.dart` | “Sin conexión” / pendientes / conflictos |
| Duplicado registrado | `RegistradosRepository.onInsert` | Unique `(evento_id, email)` → se descarta y sigue |
| Duplicado lead | `LeadsRepository.onInsert` | `TerminalSyncConflictException` + hoja de conflictos |

**No hay:** Hive, Isar, SQLite/Drift, `cached_network_image`. El volumen
acordado (~10 eventos × 200–1000 registrados) cabe en la caché JSON actual
más archivos para fotos. No se migra a SQLite en este plan.

**RLS (no se relaja):** admin/organizador ven todos los eventos; `user` y
`externo` solo los asignados en `usuarios_eventos`. El snapshot respeta eso:
no se pide al servidor lo que RLS niega.

---

## 3. Objetivo

```
iOS/Android + sesión previa
  → perfil de disco (nunca signOut por falta de red)
  → UI lee siempre de disco
  → si hay red: snapshot en segundo plano (completo la primera vez)
  → acreditar y leads → cola → sync al volver la red
  → alta/edición de asistente, perfil, Excel, etc. → toast “sin conexión”

Windows / Mac / Web
  → sin red real: overlay a pantalla completa
  → Login y recuperar contraseña se ven
  → no hay modo caché operativo
```

La UI **nunca** depende de que el fetch actual funcione. Disco = fuente de
verdad en pantalla. Red = refresco y vaciado de cola.

---

## 4. Decisiones de producto (cerradas)

### 4.1 Plataformas

- **iOS/Android:** modo offline con caché + colas.
- **Windows, Mac, Web:** sin red se bloquea el uso. Overlay encima de la app
  (icono de wifi en rojo + “Sin conexión”). No se implementa snapshot
  operativo ahí.
- **Login y recuperar contraseña** quedan visibles en escritorio/web (el
  overlay no los cubre).
- Formulario público `/r/:eventoId`: **no se toca**.

### 4.2 Recorte del snapshot

Solo eventos **`activo == true` y no finalizados** (`fecha >= hoy`, mismo
criterio que `eventoExternoOperable`). Un evento pausado por el admin no se
baja al teléfono.

A medianoche **no** se borra de disco el evento que se está usando. Deja de
refrescarse en la **próxima** sync con red.

### 4.3 Alcance por rol

| Rol | Eventos en caché | Registrados | Leads | Fotos |
|-----|------------------|-------------|-------|-------|
| Admin / organizador | Todos los activos no finalizados (RLS ya lo da) | Listas completas | Todos | Portadas de eventos/actividades, avatares |
| `user` | **Solo asignados** | Esas listas | Los propios (como ahora) | Igual |
| `externo` | **Solo asignados** | Padrón **en silencio** (lookup QR), **sin UI de lista** | Los propios | Portada del evento + avatar |

No se cachean fotos de leads ya guardados. La foto **nueva** al capturar un
lead sí se guarda en disco (`PendingPhotoStore`) y se sube al sync.

### 4.4 Escritura sin internet (móvil)

**Sí, cola, sync después, toast si duplicado:**

- Acreditar a alguien que **ya está** en el padrón (lista o QR).
- Escáner con toggle de lead: **acreditar + lead**, igual que con internet.
- Alta de lead (QR o formulario manual).
- **Edición** de lead.

**No, toast “sin conexión”, no se encola:**

- Formulario **Registrar asistente** (alta nueva).
- Editar ficha de un **registrado**.
- Crear/editar evento, gestionar usuarios, Excel, import.
- Cambiar foto, nombre o contraseña de perfil.

QR que no es del evento / no está en el padrón: mensaje actual
(“no válido o no pertenece a este evento”). No se abre un form vacío.

Duplicado **local** (mismo lead o ya acreditado en caché): toast al toque,
no se encola. Duplicado **en servidor** al sync: se omite ese ítem, se
sigue con el resto, toast de aviso.

### 4.5 Sesión y contraseña

- Login la primera vez **requiere red**.
- Si ya había sesión: entra offline con perfil cacheado.
- **Nunca** `signOut()` por timeout de splash ni por error de red al pedir
  el perfil.
- Logout solo: usuario lo pide, cuenta `activo = false` **confirmado con
  red**, o refresh de token fallido **con red**.
- Contraseña: solo se cambia en **Mi perfil**, con red. Sin red queda la
  anterior.
- Si `cambiar_pass = true` y **no hay red**: no se traba en `/recrear-pass`;
  opera con la clave vieja. Con red, el flujo obligatorio actual se mantiene.

### 4.6 Usuario externo

- No ve lista de registrados, no acredita, no registra asistentes.
- Solo captura (y edita) leads.
- El CTA deja de ser el escáner de acreditación: **captura de lead**. El QR
  de un asistente **prefilla** el form usando el padrón silencioso.
- Header como internos: foto + engranaje de ajustes. **Sin campana** de
  notificaciones.
- Foto → Mi perfil (datos de cuenta + sus leads; sin stats de
  acreditación/registros/eventos creados).
- Menú de ajustes: Mi perfil, Sincronización, Actualizaciones (si la
  plataforma aplica), Cerrar sesión.
- Logout sale del botón “atrás” de la cabecera y vive en el menú.
- Si el evento deja de ser operable **estando offline**: se queda en el
  último cacheado. **No** se cierra sesión. Solo se bloquea/cierra si **con
  internet** se confirma que no le queda ningún evento.

### 4.7 Sincronización

- Primera apertura del dispositivo (sin caché): espera el snapshot en
  splash, con progreso.
- Aperturas siguientes: entra con disco, refresca en segundo plano.
- No hay sync incremental por `updated_at`. Con ~10 eventos se **vuelve a
  bajar el set activo y se reemplaza** la caché. Lo ya finalizado se elimina
  de disco en esa pasada.
- Fallo parcial: si fallan fotos de un evento, se guardan las listas igual
  y se reintentan las fotos.
- Ajustes → **Sincronización**: última fecha, pendientes (leads /
  acreditaciones), errores, botón “Sincronizar ahora”.

---

## 5. Arquitectura propuesta

```
Arranque
  bootstrap (prefs + Supabase)
  sesión?
    no  → Login
    sí  → perfil: red si hay, si no disco
          iOS/Android: UI desde store local
          si online: SnapshotService (fondo; bloquea splash solo sin caché)
          escritorio/web: si offline (ping) → overlay, salvo login/recuperar

Escrituras (solo iOS/Android)
  acreditar / lead insert|update  → SyncQueue → SyncCoordinator
  registrar asistente / editar registrado / perfil  → toast y corte

Sync
  ítem a ítem
  duplicado → omitir + toast
  luego refetch del set activo → reemplazar caché
```

### 5.1 Store local

Extender `OfflineReadCache` (SharedPreferences, clave por usuario):

- `perfil` (snapshot del perfil de negocio)
- `eventos` / `eventos_leads` (catálogo activo)
- `usuarios` (lista de perfiles visible)
- `fijados` (eventos y actividades)
- `registrados` / `leads` (ya existe, por evento)
- metadatos de sync (`last_success_at`, alcance)

Fotos: archivos en disco (prefetch de URLs de portada y avatar). En UI,
resolver disco primero y red después. No usar `cached_network_image` en web
(histórico: fallaba al segundo pintado); el prefetch es **solo IO**.

### 5.2 SnapshotService

Nuevo servicio (Riverpod), disparado:

1. Tras perfil resuelto, si hay red (iOS/Android).
2. Desde Ajustes → Sincronizar ahora.
3. Tras vaciar la cola con éxito (refresco).

Orden sugerido:

1. Perfil actual → disco.
2. Eventos (filtro activo + no finalizado; RLS recorta por rol).
3. Actividades de leads del mismo recorte, más el mapa
   `evento_origen_id → evento_lead` (hace falta para el form de lead offline;
   no crear actividades nuevas sin red).
4. Usuarios + URLs de avatar.
5. Fijados / cards del home.
6. Por cada evento del set: registrados y leads (según `canViewAllLeads`).
7. Prefetch de imágenes a disco.

Providers de lista: **leen disco primero**, refrescan atrás si hay red, y
**nunca** reemplazan una lista buena por vacío/error de transporte.

### 5.3 Detección de red (escritorio/web)

`connectivity_plus` no basta para un overlay que congela toda la app.

- Combinar interfaz + **ping** (HEAD/GET liviano a Supabase).
- Debounce 1–2 s antes de mostrar/ocultar el overlay.
- Default optimista corto para no flashar el overlay al abrir.

En móvil el banner puede seguir usando el stream actual; las decisiones de
escritura (`enqueue` vs toast) siguen clasificando errores de transporte
(`isNetworkTransportError`).

### 5.4 Overlay escritorio/web

Widget a nivel de `MaterialApp` / raíz post-bootstrap:

- Visible si plataforma **no** es iOS/Android y no hay red real.
- **No** visible en Login ni Recuperar contraseña.
- Cubre el resto: no se puede navegar ni pulsar la app de debajo.
- Copy: “Sin conexión” + icono wifi en rojo. Sin botón de sync (no hay
  modo caché en estas plataformas).

### 5.5 Política de plataforma

Un único helper, p. ej. `OfflinePolicy`:

- `supportsOfflineCache` → iOS || Android
- `blocksUiWhenOffline` → web || Windows || macOS (o `!supportsOfflineCache`)
- `isAuthGateRoute` → login / recuperar contraseña

---

## 6. Cambios por área y archivos

### Fase 0 — Sesión, banner, overlay

Desbloquea los 4 bugs visibles y el bloqueo de escritorio.

| Cambio | Dónde |
|--------|--------|
| Cachear `Perfil`; `currentPerfilProvider` usa disco si la red falla | `lib/features/auth/providers/auth_providers.dart`, `OfflineReadCache` |
| Timeout de splash **no** llama `signOut()`; si hay perfil en disco, entra | `lib/core/router/app_router.dart`, `session_boot_route.dart`, `splash_screen.dart` |
| Si `cambiar_pass` y offline, no forzar `/recrear-pass` | `app_router.dart` |
| Padding de status bar en el banner | `lib/core/widgets/offline_banner.dart`, `app_scaffold.dart`, `home_screen.dart`, hubs |
| Overlay + ping en Windows/Mac/web | nuevo widget + `app.dart` / `connectivity_service.dart` |
| Externo offline no cierra sesión por “no operable” | `usar_evento_externo_screen.dart`, `externoEventoBloqueadoProvider` |

### Fase 1 — Catálogo local (deja de vaciar listas)

| Cambio | Dónde |
|--------|--------|
| `leerConRespaldo` para eventos, actividades, usuarios, fijados, `eventoById` | `eventos_providers.dart`, `capturador_providers.dart`, `usuarios_providers.dart`, `fijados_providers.dart` |
| Refresh: mostrar local, invalidar sin borrar | `listar_eventos_screen.dart` (`RefreshOnVisible`), home, hubs |
| Filtrar listas a activos no finalizados en el store | al guardar el snapshot |

### Fase 2 — Snapshot + pantalla de sync

| Cambio | Dónde |
|--------|--------|
| `SnapshotService` | `lib/data/offline/snapshot_service.dart` (nuevo) |
| Progreso en splash solo si no hay caché | `splash_screen.dart` |
| Ajustes → Sincronización | nueva pantalla + ruta; ítem en `_MenuCuenta` (`home_screen.dart`) y menú del externo |
| Metadatos last sync / pendientes | prefs + providers de cola existentes |

### Fase 3 — Reglas de escritura

| Cambio | Dónde |
|--------|--------|
| Registrar asistente: si offline, toast y no `enqueueInsert` | `registro_por_cliente_screen.dart`, `registrar_confirmado_screen.dart` |
| Editar registrado: toast, no cola | `editar_registrado_screen.dart` |
| Acreditar (lista y QR): **mantener** `enqueueUpdate` | `ver_registrados_screen.dart`, `acreditar_qr_screen.dart`, `acreditar_confirmado_screen.dart` |
| Toggle lead + offline: acreditar en cola **y** abrir form (igual que online) | `acreditar_qr_screen.dart` (`_procesarCapturarLead`) |
| Alta/edición lead: mantener cola | `crear_lead_screen.dart`, `lista_leads_screen.dart` |
| Duplicados al sync: omitir + toast (leads dejan de quedar en hoja bloqueante) | `leads_repository.dart`, `sync_queue_service.dart`, `offline_banner.dart` / listener |
| Duplicado local antes de encolar | pantallas de lead y acreditar |
| Perfil (foto/nombre/clave) offline: toast | `mi_perfil_screen.dart` |

### Fase 4 — Externo

| Cambio | Dónde |
|--------|--------|
| Header: foto + ajustes, sin campana | `usar_evento_externo_screen.dart` |
| Abrir Mi perfil (quitar `usesFullShell` o allowlist) | `mi_perfil_screen.dart`, `app_router.dart`, `external_route_policy.dart` |
| Stats de perfil: solo leads para externo | `perfil_providers.dart` / UI de perfil |
| CTA: captura de lead, no acreditar | hero del externo; no navegar a `acreditarQr` |
| Allowlist: ruta capturar lead (manual y desde QR) | `external_route_policy.dart` |
| Padrón silencioso (ya se precarga); no mostrar “Ver registrados” | `usar_evento_externo_screen.dart` |
| Logout en el menú, no en `onBack` | mismo archivo |

### Fase 5 — Fotos a disco

| Cambio | Dónde |
|--------|--------|
| Prefetch de portadas y avatares en el snapshot | nuevo store de imágenes IO |
| `AppNetworkImage` en iOS/Android: archivo local si existe | `lib/core/widgets/app_network_image.dart` |
| Web/desktop: se deja `Image.network` (no hay modo offline operativo) | mismo |

---

## 7. Comportamiento del escáner (resumen)

| Quién | Toggle lead | Con internet | Sin internet |
|-------|-------------|--------------|--------------|
| Interno | Off | Acredita | Acredita en cola |
| Interno | On | Acredita si hace falta + form lead | Acredita en cola + form lead (cola) |
| Externo | N/A (siempre lead) | Form lead (prefill si el QR es del padrón) | Form lead en cola; **no** acredita |
| Cualquiera | QR ajeno | “No válido / no pertenece” | Igual |

`obtenerOCrearEventoLeadInterno` **no crea** la actividad offline. El
snapshot debe haber guardado el vínculo; si no existe, toast de que hace
falta haber sincronizado antes.

---

## 8. Fuera de alcance

- Formulario público de autoregistro (otro proyecto).
- SQLite/Drift.
- Sync incremental/CDC por `updated_at`.
- Abrir RLS para que un `user`/`externo` baje eventos ajenos.
- Caché operativa en Windows/Mac/web.
- Fotos históricas de leads.
- Notificaciones push / campana para externos.
- Alta de asistente, edición de registrado, Excel, ABM de eventos/usuarios
  sin red.
- Login con usuario/clave sin red.

---

## 9. Criterios de aceptación

**Móvil, ya logueado, avión:**

- [ ] No vuelve a Login.
- [ ] Listas de eventos asignados (o todos, si admin/org) se ven.
- [ ] Se entra al detalle del evento.
- [ ] Se ve la lista de registrados (interno) y no se vacía al recargar.
- [ ] Acreditar (lista o QR) queda pendiente y se sube al volver la red.
- [ ] Capturar / editar lead queda pendiente y se sube al volver la red.
- [ ] Registrar asistente y editar registrado muestran toast y no cambian nada.
- [ ] Banner debajo de la hora.
- [ ] Fotos de evento/actividad/avatar se ven si se sincronizó antes.
- [ ] Externo: ajustes + Mi perfil por la foto; no campana; no lista de
      registrados; QR → form lead; no se cierra la sesión solo.

**Móvil, primera instalación, con red:**

- [ ] Splash espera el snapshot y luego entra con datos completos.

**Móvil, segunda apertura, con red:**

- [ ] Entra de inmediato con caché; sync en fondo.
- [ ] Ajustes → Sincronizar ahora fuerza un snapshot.

**Sync:**

- [ ] Lead o registrado duplicado en BD: se omite, toast, el resto sigue.

**Windows / Mac / Web:**

- [ ] Cortar red (de verdad) → overlay, app inutilizable.
- [ ] Login y recuperar contraseña se ven.
- [ ] Volver la red → overlay desaparece (tras debounce/ping).

---

## 10. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| JWT vencido tras días sin abrir | Offline se opera con perfil en disco. Al volver online, refresh; si falla de verdad, Login |
| Wi‑Fi sin internet en escritorio | Ping a Supabase, no solo `connectivity_plus` |
| Snapshot a medias | Guardar por tabla/evento; fotos al final; reintentos |
| Crear actividad de captura offline | Prohibido; snapshot del mapa evento → actividad |
| Externo + evento finalizado a las 00:00 | No evict inmediato; próxima sync con red |
| SharedPreferences grande | ~10k filas JSON es aceptable; no Drift en este plan |
| Hoja de conflictos de leads vs toast | Cambiar duplicados a omitir + toast para no trabar feria |

---

## 11. Orden de implementación

1. Fase 0 — sesión, banner, overlay escritorio.
2. Fase 1 — caché de catálogo y providers que no vacían.
3. Fase 2 — SnapshotService + pantalla de sincronización.
4. Fase 3 — reglas de escritura y duplicados.
5. Fase 4 — shell y flujos del externo.
6. Fase 5 — prefetch de fotos.

Cada fase debe dejar la app compilable y usable online como hoy. No mezclar
el rediseño del externo con el overlay de Windows en el mismo cambio.
