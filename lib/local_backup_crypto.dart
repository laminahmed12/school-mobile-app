import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Authenticated encryption for device-local backups.
/// The encryption key is managed separately by flutter_secure_storage.
class LocalBackupCrypto {
  LocalBackupCrypto._();

  static const format = 'lamin-encrypted-local-backup';
  static const version = 1;
  static final AesGcm _cipher = AesGcm.with256bits();

  static List<int> _associatedData(String schoolId) =>
      utf8.encode('lamin-local-backup:$version:$schoolId');

  static Future<Map<String, dynamic>> encryptText({
    required String clearText,
    required SecretKey key,
    required String schoolId,
  }) async {
    if (schoolId.trim().isEmpty) {
      throw ArgumentError.value(schoolId, 'schoolId', 'must not be empty');
    }
    final box = await _cipher.encrypt(
      utf8.encode(clearText),
      secretKey: key,
      aad: _associatedData(schoolId),
    );
    return {
      'format': format,
      'version': version,
      'school_id': schoolId,
      'nonce': base64Encode(box.nonce),
      'cipher_text': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  static Future<String> decryptText({
    required Map<String, dynamic> envelope,
    required SecretKey key,
    required String expectedSchoolId,
  }) async {
    if (envelope['format'] != format ||
        envelope['version'] != version ||
        envelope['school_id']?.toString() != expectedSchoolId) {
      throw const FormatException(
        'Encrypted local backup format or school does not match.',
      );
    }

    try {
      final nonce = base64Decode(envelope['nonce'].toString());
      final cipherText = base64Decode(envelope['cipher_text'].toString());
      final macBytes = base64Decode(envelope['mac'].toString());
      if (nonce.length != 12 || macBytes.length != 16 || cipherText.isEmpty) {
        throw const FormatException('Encrypted local backup is incomplete.');
      }
      final box = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final clearBytes = await _cipher.decrypt(
        box,
        secretKey: key,
        aad: _associatedData(expectedSchoolId),
      );
      return utf8.decode(clearBytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Local backup authentication failed or its data was modified.',
      );
    }
  }
}
