import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/device_identity.dart';

void main() {
  group('Android device identity', () {
    test('accepts a SHA-256 public-key fingerprint', () {
      final fingerprint = List.filled(64, 'a').join();
      final identity = LaminDeviceIdentity.fromMap({
        'device_id': fingerprint,
        'public_key': 'public-key-base64',
        'hardware_backed': true,
      });

      expect(identity.deviceId, fingerprint);
      expect(identity.displayId, 'A' * 16);
      expect(identity.hardwareBacked, isTrue);
    });

    test('rejects malformed device identifiers', () {
      expect(
        () => LaminDeviceIdentity.fromMap({
          'device_id': 'imei-123456',
          'public_key': 'public-key-base64',
          'hardware_backed': false,
        }),
        throwsFormatException,
      );
    });

    test('rejects missing public key material', () {
      expect(
        () => LaminDeviceIdentity.fromMap({
          'device_id': List.filled(64, 'b').join(),
          'public_key': '',
          'hardware_backed': false,
        }),
        throwsFormatException,
      );
    });
  });
}
