{{flutter_js}}
{{flutter_build_config}}

const recoveryMarker = 'regispro-flutter-cache-recovery-v1';

function repairCorruptedRouteState() {
  const routeState = history.state?.state;
  const encoded = routeState?.encoded;
  if (
    routeState?.codec === 'json' &&
    typeof encoded === 'string' &&
    encoded.trimStart().startsWith('<!DOCTYPE')
  ) {
    history.replaceState(null, '', location.href);
  }
}

async function startupResourcesNeedRecovery() {
  const startupResources = [
    'assets/AssetManifest.bin.json',
    'assets/FontManifest.json',
    'version.json',
    'assets/assets/motion/transworld-logo-draw.json',
  ];
  let needsRecovery = false;

  for (const resourceUrl of startupResources) {
    const response = await fetch(resourceUrl);
    const contentType = response.headers.get('content-type') ?? '';
    if (response.ok && contentType.includes('application/json')) continue;

    needsRecovery = true;
    // `no-store` solo omite la copia mala durante esta petición. `reload`
    // reemplaza la entrada HTTP que Flutter volverá a solicitar enseguida.
    await fetch(resourceUrl, { cache: 'reload' });
  }

  return needsRecovery;
}

async function recoverBrokenFlutterCache() {
  if (sessionStorage.getItem(recoveryMarker) === 'done') return false;
  if (!(await startupResourcesNeedRecovery())) return false;

  sessionStorage.setItem(recoveryMarker, 'done');

  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((registration) => registration.unregister()));
  }

  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
  }

  location.reload();
  return true;
}

async function bootRegisPro() {
  repairCorruptedRouteState();
  try {
    if (await recoverBrokenFlutterCache()) return;
  } catch (_) {
    // Si el navegador no permite limpiar caché, Flutter conserva su arranque
    // normal y mostrará cualquier error mediante el manejo existente.
  }

  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
  });
}

bootRegisPro();
