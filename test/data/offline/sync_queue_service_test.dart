import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';

void main() {
  group('esIdSoloLocal', () {
    test('reconoce el id temporal de un insert encolado', () {
      expect(esIdSoloLocal('${syncLocalIdPrefix}abc-123'), isTrue);
    });

    test('un uuid del servidor no es local', () {
      expect(
        esIdSoloLocal('a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
        isFalse,
      );
    });

    test('no confunde un uuid que contenga "local" más adelante', () {
      expect(esIdSoloLocal('abc-local_123'), isFalse);
    });
  });
}
