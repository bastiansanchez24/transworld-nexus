import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/features/updates/services/update_platform.dart';

void main() {
  test('Android y Windows tienen OTA; iOS y web son historial', () {
    expect(
      otaUpdatesSupportedFor(TargetPlatform.android, isWeb: false),
      isTrue,
    );
    expect(
      otaUpdatesSupportedFor(TargetPlatform.windows, isWeb: false),
      isTrue,
    );
    expect(otaUpdatesSupportedFor(TargetPlatform.iOS, isWeb: false), isFalse);
    expect(
      otaUpdatesSupportedFor(TargetPlatform.android, isWeb: true),
      isFalse,
    );
  });
}
