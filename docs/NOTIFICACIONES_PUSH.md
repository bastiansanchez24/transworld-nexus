# Notificaciones push (Firebase + Supabase)

Proyecto Supabase: **NEXUS - TW_P&T** (`evjocwzmlsyjixzihxep`)

## Estado actual (ya aplicado en Supabase)

- [x] Migración SQL (`notificaciones`, `notificaciones_leidas`, `device_tokens`, RLS, trigger)
- [x] Realtime habilitado en `public.notificaciones`
- [x] Edge Function `enviar-push` desplegada

## Pendiente (manual en dashboards)

- [ ] Database Webhook (INSERT → `enviar-push`) — ver sección 2
- [ ] Secret `FIREBASE_SERVICE_ACCOUNT_JSON` en Edge Functions — ver sección 3
- [ ] Configuración Firebase + archivos en el repo Flutter — ver sección 4

---

## 1. Inbox in-app (sin Firebase)

Con la migración ya aplicada, el inbox funciona en la app:

- Campana en home / vista externo → `/notificaciones`
- Cada INSERT en `registrados` crea: **"Nombre se registró a Evento"**
- Al acreditar asistentes, hitos al **20%, 50%, 80% y 100%** (una vez por evento)
- Se actualiza en tiempo real con la app abierta

Para probar: registra a alguien en un evento y abre la campana.

---

## 2. Webhook Supabase (activar push)

Supabase movió los webhooks: **ya no están en Database**. Usa **Integrations → Webhooks**.

**Enlace directo a tu proyecto:**

https://supabase.com/dashboard/project/evjocwzmlsyjixzihxep/integrations/webhooks/overview

**Ruta en el dashboard:**

1. Abre tu proyecto **NEXUS - TW_P&T**
2. Menú lateral → **Integrations** (Integraciones)
3. **Webhooks** → **Create a new hook**

| Campo | Valor |
|-------|--------|
| Name | `notificaciones-enviar-push` |
| Table | `public.notificaciones` |
| Events | `INSERT` |
| Type | HTTP Request (o Supabase Edge Function si aparece la opción) |
| URL | `https://evjocwzmlsyjixzihxep.supabase.co/functions/v1/enviar-push` |
| HTTP method | POST |
| HTTP headers | `Authorization: Bearer <SERVICE_ROLE_KEY>` |
| Payload | JSON con la fila insertada (por defecto incluye `record`) |

El `SERVICE_ROLE_KEY` está en **Project Settings → API → service_role** (no lo compartas ni lo subas al repo).

Si no ves **Integrations** en el menú, prueba el enlace directo de arriba o busca **Webhooks** en la barra de búsqueda del dashboard.

---

## 3. Secret Firebase en Supabase

Después de crear la service account en Firebase (paso 4.4):

Dashboard → **Edge Functions → Secrets** → agregar:

| Secret | Valor |
|--------|--------|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | JSON completo de la service account (una sola línea o pegado tal cual) |

---

## 4. Firebase — instrucciones paso a paso

FCM es **gratuito**. No necesitas plan de pago Blaze solo por push.

**No versionar** estos archivos (están en `.gitignore`): `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`. Obténlos por Firebase Console / `flutterfire configure` y colócalos localmente (canales seguros del equipo). `firebase.json` (rutas de salida FlutterFire) sí puede vivir en el repo.

### 4.1 Crear proyecto

1. Entra a [Firebase Console](https://console.firebase.google.com/)
2. **Add project** (o usa uno existente de Transworld)
3. Desactiva Google Analytics si no lo necesitas → Create

### 4.2 App Android

1. En el proyecto → **Add app** → **Android**
2. **Package name:** `com.transworld.nexus` (debe coincidir con `android/app/build.gradle.kts`)
3. Descarga **`google-services.json`**
4. Colócalo en: `android/app/google-services.json`
5. Finish (no hace falta agregar el SDK manualmente; Flutter lo hace)

### 4.3 App iOS (si publicas en iPhone)

1. **Add app** → **iOS**
2. **Bundle ID:** `com.transworld.nexus`
3. Descarga **`GoogleService-Info.plist`**
4. Colócalo en: `ios/Runner/GoogleService-Info.plist`
5. En Xcode: abre `ios/Runner.xcworkspace` → Runner → **Signing & Capabilities** → **+ Capability** → **Push Notifications**

### 4.4 Service account (para la Edge Function)

1. Firebase → **Project settings** (engranaje) → pestaña **Service accounts**
2. **Generate new private key** → descarga el JSON
3. En Supabase → **Edge Functions → Secrets** → pega ese JSON como `FIREBASE_SERVICE_ACCOUNT_JSON`

### 4.5 APNs para iOS (solo push en dispositivos Apple)

1. [Apple Developer](https://developer.apple.com/) → **Certificates, Identifiers & Profiles**
2. **Keys** → crea una key con **Apple Push Notifications service (APNs)**
3. Descarga el archivo `.p8` (solo se descarga una vez)
4. Firebase → **Project settings → Cloud Messaging → Apple app configuration**
5. Sube la APNs key (.p8), **Key ID** y **Team ID**

### 4.6 Generar `firebase_options.dart` en Flutter

En la raíz del proyecto (con Firebase CLI / FlutterFire):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<tw-nexus-app>
```

Esto regenera `lib/firebase_options.dart` con valores reales (reemplaza los `REPLACE_ME`).

### 4.7 Probar push

1. Instala la app en un dispositivo físico (Android o iOS)
2. Inicia sesión (registra el token FCM en `device_tokens`)
3. Desde otra sesión o formulario público, registra a alguien en un evento
4. Deberías recibir banner del sistema + ver el aviso en el inbox

---

## 5. Comportamiento

| Plataforma | Inbox in-app | Push sistema |
|------------|--------------|--------------|
| Android | Sí | Sí (con Firebase) |
| iOS | Sí | Sí (con Firebase + APNs) |
| Web / Desktop | Sí | No (solo inbox) |

Destinatarios: **todos** los usuarios autenticados con token registrado.
