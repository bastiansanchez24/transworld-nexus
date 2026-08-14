import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:transworld_nexus/features/acreditacion/scanner/camera_service.dart';
import 'package:transworld_nexus/features/acreditacion/scanner/scanner_controller.dart';
import 'package:transworld_nexus/features/acreditacion/scanner/web_camera_tracks.dart';

void main() {
  test('stopOrphanWebCameraTracks es no-op en tests VM', () {
    expect(stopOrphanWebCameraTracks, returnsNormally);
  });

  test('stopCamera y dispose no lanzan con el controlador detenido', () async {
    final camera = CameraService(
      controller: MobileScannerController(autoStart: false),
    );
    final scanner = ScannerController(cameraService: camera);

    await scanner.stopCamera();
    scanner.dispose();
  });
}
