import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Corta los [MediaStreamTrack] de previews `<video>` (getUserMedia).
///
/// `mobile_scanner` 7.4, con BarcodeDetector / zxing-wasm, hace `stop()`
/// sin `track.stop()`. El navegador deja el indicador de cámara encendido.
void stopOrphanWebCameraTracks() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node == null) continue;
    final video = node as web.HTMLVideoElement;
    final stream = video.srcObject;
    if (stream == null || !stream.isA<web.MediaStream>()) continue;
    final mediaStream = stream as web.MediaStream;
    for (final track in mediaStream.getTracks().toDart) {
      track.stop();
    }
    video
      ..srcObject = null
      ..pause();
  }
}
