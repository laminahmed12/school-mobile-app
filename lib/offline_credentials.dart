import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum OnlineLoginPreparationState { idle, preparing, ready, failed }

bool shouldShowLoginForm({
  required bool hasAuthenticatedSession,
  required bool offlineAccess,
  required bool preparingOnlineLogin,
  required bool onlineLoginPreparationFailed,
}) =>
    preparingOnlineLogin ||
    onlineLoginPreparationFailed ||
    (!hasAuthenticatedSession && !offlineAccess);

/// One encrypted record binds the password verifier to the cached school and
/// account eligibility. The password itself is never stored.
class LaminOfflineCredentialStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int _iterations = 60000;
  static const String _identityKey = 'lamin.offline.identity.v2';

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

  Future<Map<String, dynamic>?> readIdentity() async {
    try {
      final raw = await _storage.read(key: _identityKey);
      if (raw == null) return null;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (saved['version'] != 2 ||
          saved['user_id'] is! String ||
          (saved['user_id'] as String).isEmpty ||
          saved['school_id'] is! String ||
          (saved['school_id'] as String).isEmpty ||
          saved['school_code'] is! String ||
          (saved['school_code'] as String).isEmpty ||
          saved['username'] is! String ||
          (saved['username'] as String).isEmpty ||
          saved['salt'] is! String ||
          saved['verifier'] is! String ||
          saved['iterations'] != _iterations ||
          saved['profile_active'] is! bool ||
          saved['must_change_password'] is! bool ||
          saved['school_active'] is! bool ||
          saved['licensed'] is! bool) {
        return null;
      }
      return saved;
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String userId,
    required String schoolId,
    required String schoolCode,
    required String username,
    required String password,
    required bool profileActive,
    required bool mustChangePassword,
    required bool schoolActive,
    required bool licensed,
    required String? trialStartedAt,
    required String role,
  }) async {
    if (userId.trim().isEmpty ||
        schoolId.trim().isEmpty ||
        schoolCode.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty) {
      throw ArgumentError('Offline credential fields must not be empty.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final verifier = await _derive(password, salt);
    final payload = {
      'version': 2,
      'user_id': userId,
      'school_id': schoolId,
      'school_code': schoolCode.trim().toLowerCase(),
      'username': username.trim().toLowerCase(),
      'profile_active': profileActive,
      'must_change_password': mustChangePassword,
      'school_active': schoolActive,
      'licensed': licensed,
      'trial_started_at': trialStartedAt,
      'role': role,
      'salt': base64Encode(salt),
      'verifier': base64Encode(verifier),
      'iterations': _iterations,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _storage.write(key: _identityKey, value: jsonEncode(payload));
    final persisted = await readIdentity();
    if (persisted == null ||
        persisted['user_id'] != userId ||
        persisted['school_id'] != schoolId ||
        persisted['school_code'] != schoolCode.trim().toLowerCase() ||
        persisted['username'] != username.trim().toLowerCase()) {
      throw StateError('Offline identity record did not persist correctly.');
    }
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
      final saved = await readIdentity();
      if (saved == null ||
          saved['user_id'] != userId ||
          saved['school_code'] != schoolCode.trim().toLowerCase() ||
          saved['username'] != username.trim().toLowerCase()) {
        return false;
      }

      final salt = base64Decode(saved['salt'].toString());
      final expected = base64Decode(saved['verifier'].toString());
      final actual = await _derive(password, salt);
      if (actual.length != expected.length) return false;

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
    final saved = await readIdentity();
    return saved != null &&
        saved['user_id'] == userId &&
        saved['school_code'] == schoolCode.trim().toLowerCase() &&
        saved['username'] == username.trim().toLowerCase();
  }

  Future<void> remove(String userId) async {
    final saved = await readIdentity();
    if (saved?['user_id'] == userId) {
      await _storage.delete(key: _identityKey);
    }
    await _storage.delete(key: 'lamin.offline.credential.v1.$userId');
  }
}
