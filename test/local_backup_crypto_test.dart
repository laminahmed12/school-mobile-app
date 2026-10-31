import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/local_backup_crypto.dart';

void main() {
  const schoolId = 'school-a';
  final key = SecretKey(List<int>.generate(32, (index) => index));

  const clearText =
      '{"format":"lamin-school-backup","version":2,"school_id":"school-a"}';

  group('LocalBackupCrypto', () {
    test('encrypts and decrypts a local backup', () async {
      final encrypted = await LocalBackupCrypto.encryptText(
        clearText: clearText,
        key: key,
        schoolId: schoolId,
      );

      expect(encrypted['format'], LocalBackupCrypto.format);
      expect(encrypted['cipher_text'], isNot(clearText));

      final decrypted = await LocalBackupCrypto.decryptText(
        envelope: encrypted,
        key: key,
        expectedSchoolId: schoolId,
      );

      expect(decrypted, clearText);
    });

    test('rejects a backup bound to a different school', () async {
      final encrypted = await LocalBackupCrypto.encryptText(
        clearText: clearText,
        key: key,
        schoolId: schoolId,
      );

      await expectLater(
        LocalBackupCrypto.decryptText(
          envelope: encrypted,
          key: key,
          expectedSchoolId: 'school-b',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('detects ciphertext tampering', () async {
      final encrypted = await LocalBackupCrypto.encryptText(
        clearText: clearText,
        key: key,
        schoolId: schoolId,
      );
      final bytes = base64Decode(encrypted['cipher_text'] as String);
      bytes[0] ^= 1;
      final tampered = {
        ...encrypted,
        'cipher_text': base64Encode(bytes),
      };

      await expectLater(
        LocalBackupCrypto.decryptText(
          envelope: tampered,
          key: key,
          expectedSchoolId: schoolId,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects incomplete or unsupported encrypted envelopes', () async {
      await expectLater(
        LocalBackupCrypto.decryptText(
          envelope: {'format': LocalBackupCrypto.format, 'version': 99},
          key: key,
          expectedSchoolId: schoolId,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
