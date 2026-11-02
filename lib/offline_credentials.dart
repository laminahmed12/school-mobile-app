import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Verifies a previously authenticated account offline without storing the
/// user's password. The verifier is scoped to both the Supabase user ID and
/// the school code and is stored only in the platform secure store.
class LaminOfflineCredentialStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int _iterations = 60000;
  static const String _keyPrefix = 'lamin.offline.credential.v1.';

  String _key(String userId) => '$_keyPrefix$userId';

  Future<List<int>> _derive(String password, List<int> salt) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final secret = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return secret.extractBytes();
  }

  Future<void> save({
    required String userId,
    required String schoolCode,
    required String username,
    required String password,
  }) async {
    if (userId.isEmpty ||
        schoolCode.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty) {
      throw ArgumentError('Offline credential fields must not be empty.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final verifier = await _derive(password, salt);
    final payload = {
      'version': 1,
      'user_id': userId,
      'school_code': schoolCode.trim().toLowerCase(),
      'username': username.trim().toLowerCase(),
      'salt': base64Encode(salt),
      'verifier': base64Encode(verifier),
      'iterations': _iterations,
    };
    await _storage.write(key: _key(userId), value: jsonEncode(payload));
  }

  Future<bool> verify({
    required String userId,
    required String schoolCode,
    required String username,
    required String password,
  }) async {
    if (userId.isEmpty ||
        schoolCode.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty) {
      return false;
    }

    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null) return false;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);

      if (saved['version'] != 1 ||
          saved['user_id'] != userId ||
          saved['school_code'] != schoolCode.trim().toLowerCase() ||
          saved['username'] != username.trim().toLowerCase() ||
          saved['iterations'] != _iterations) {
        return false;
      }

      final salt = base64Decode(saved['salt'].toString());
      final expected = base64Decode(saved['verifier'].toString());
      final actual = await _derive(password, salt);
      if (actual.length != expected.length) return false;

      // Constant-time comparison prevents an early-exit timing signal.
      var difference = 0;
      for (var index = 0; index < actual.length; index++) {
        difference |= actual[index] ^ expected[index];
      }
      return difference == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasCredential({
    required String userId,
    required String schoolCode,
    required String username,
  }) async {
    if (userId.isEmpty || schoolCode.trim().isEmpty || username.trim().isEmpty) {
      return false;
    }
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null) return false;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return saved['version'] == 1 &&
          saved['user_id'] == userId &&
          saved['school_code'] == schoolCode.trim().toLowerCase() &&
          saved['username'] == username.trim().toLowerCase() &&
          saved['iterations'] == _iterations &&
          saved['salt'] is String &&
          saved['verifier'] is String;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String userId) => _storage.delete(key: _key(userId));
}
