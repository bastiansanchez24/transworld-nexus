import 'web_camera_tracks_stub.dart'
    if (dart.library.js_interop) 'web_camera_tracks_web.dart'
    as impl;

/// En web, detiene tracks de cámara huérfanos. En el resto de plataformas, no-op.
void stopOrphanWebCameraTracks() => impl.stopOrphanWebCameraTracks();
