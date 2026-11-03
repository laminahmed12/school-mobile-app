import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_identity.dart';

const int laminOfflineIdentityRecordVersion = 3;
const int laminOfflinePbkdf2Iterations = 60000;

/// Pure structural validation shared by cold-start recovery and unit tests.
/// Cryptographic ownership is verified separately by Android Keystore.
bool isValidLaminOfflineIdentityRecord(Map<String, dynamic> saved) {
  if (saved['version'] != laminOfflineIdentityRecordVersion ||
      saved['user_id'] is! String ||
      (saved['user_id'] as String).trim().isEmpty ||
      saved['school_id'] is! String ||
      (saved['school_id'] as String).trim().isEmpty ||
      saved['school_code'] is! String ||
      (saved['school_code'] as String).trim().isEmpty ||
      saved['username'] is! String ||
      (saved['username'] as String).trim().isEmpty ||
      saved['role'] is! String ||
      (saved['role'] as String).trim().isEmpty ||
      saved['profile_active'] is! bool ||
      saved['must_change_password'] is! bool ||
      saved['school_active'] is! bool ||
      saved['licensed'] is! bool ||
      saved['iterations'] != laminOfflinePbkdf2Iterations ||
      saved['salt'] is! String ||
      saved['verifier'] is! String ||
      saved['device_id'] is! String ||
      !RegExp(r'^[a-f0-9]{64}
bool shouldShowLoginForm({
  required bool hasAuthenticatedSession,
  required bool offlineAccess,
  required bool preparingOnlineLogin,
  required bool onlineLoginPreparationFailed,
}) =>
    preparingOnlineLogin ||
    onlineLoginPreparationFailed ||
    (!hasAuthenticatedSession && !offlineAccess);

/// One encrypted record binds the account, school, password verifier and
/// Android Keystore public-key fingerprint to this installation.
class LaminOfflineCredentialStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int _iterations = laminOfflinePbkdf2Iterations;
  static const String _identityKey = 'lamin.offline.identity.v3';
  final LaminDeviceIdentityService _deviceIdentity =
      LaminDeviceIdentityService();

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

  String _bindingChallenge(Map<String, dynamic> payload) => jsonEncode({
    'format': 'lamin-offline-device-binding-v1',
    'version': payload['version'],
    'user_id': payload['user_id'],
    'school_id': payload['school_id'],
    'school_code': payload['school_code'],
    'username': payload['username'],
    'profile_active': payload['profile_active'],
    'must_change_password': payload['must_change_password'],
    'school_active': payload['school_active'],
    'licensed': payload['licensed'],
    'trial_started_at': payload['trial_started_at'],
    'salt': payload['salt'],
    'verifier': payload['verifier'],
    'iterations': payload['iterations'],
    'device_id': payload['device_id'],
    'device_public_key': payload['device_public_key'],
  });

  Future<Map<String, dynamic>?> readIdentity() async {
    try {
      final raw = await _storage.read(key: _identityKey);
      if (raw == null) return null;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return isValidLaminOfflineIdentityRecord(saved) ? saved : null;
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

    // This key is created once in Android Keystore and is never exportable.
    final device = await _deviceIdentity.getOrCreate();
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final verifier = await _derive(password, salt);
    final payload = <String, dynamic>{
      'version': 3,
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
      'device_id': device.deviceId,
      'device_public_key': device.publicKey,
      'device_hardware_backed': device.hardwareBacked,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    };

    final challenge = _bindingChallenge(payload);
    final signature = await _deviceIdentity.signChallenge(challenge);
    final currentDevice = await _deviceIdentity.getExisting();
    if (currentDevice == null ||
        currentDevice.deviceId != device.deviceId ||
        currentDevice.publicKey != device.publicKey) {
      throw StateError('Android device key changed during local enrollment.');
    }
    payload['device_signature'] = signature;

    await _storage.write(key: _identityKey, value: jsonEncode(payload));
    final persisted = await readIdentity();
    if (persisted == null ||
        persisted['user_id'] != userId ||
        persisted['school_id'] != schoolId ||
        persisted['school_code'] != schoolCode.trim().toLowerCase() ||
        persisted['username'] != username.trim().toLowerCase() ||
        persisted['device_id'] != device.deviceId) {
      throw StateError('Device-bound offline identity did not persist correctly.');
    }
  }

  Future<bool> _isBoundToCurrentDevice(Map<String, dynamic> saved) async {
    try {
      final current = await _deviceIdentity.getExisting();
      if (current == null ||
          current.deviceId != saved['device_id'] ||
          current.publicKey != saved['device_public_key']) {
        return false;
      }
      final valid = await _deviceIdentity.verifyBinding(
        challenge: _bindingChallenge(saved),
        signature: saved['device_signature'].toString(),
        deviceId: saved['device_id'].toString(),
        publicKey: saved['device_public_key'].toString(),
      );
      return valid;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyDeviceBinding() async {
    final saved = await readIdentity();
    if (saved == null) return false;
    return _isBoundToCurrentDevice(saved);
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

      // Require the original Android Keystore private key before accepting
      // the PBKDF2 password verifier.
      if (!await _isBoundToCurrentDevice(saved)) return false;

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
    if (saved == null ||
        saved['user_id'] != userId ||
        saved['school_code'] != schoolCode.trim().toLowerCase() ||
        saved['username'] != username.trim().toLowerCase()) {
      return false;
    }
    return _isBoundToCurrentDevice(saved);
  }

  Future<void> remove(String userId) async {
    final saved = await readIdentity();
    if (saved?['user_id'] == userId) {
      await _storage.delete(key: _identityKey);
    }
    await _storage.delete(key: 'lamin.offline.credential.v1.$userId');
    await _storage.delete(key: 'lamin.offline.credential.v1');
    await _storage.delete(key: 'lamin.offline.identity.v2');
  }
}
).hasMatch(saved['device_id'] as String) ||
      saved['device_public_key'] is! String ||
      (saved['device_public_key'] as String).isEmpty ||
      saved['device_signature'] is! String ||
      (saved['device_signature'] as String).isEmpty ||
      saved['device_hardware_backed'] is! bool) {
    return false;
  }

  try {
    final salt = base64Decode(saved['salt'] as String);
    final verifier = base64Decode(saved['verifier'] as String);
    final publicKey = base64Decode(saved['device_public_key'] as String);
    final signature = base64Decode(saved['device_signature'] as String);
    return salt.length == 16 &&
        verifier.length == 32 &&
        publicKey.isNotEmpty &&
        signature.isNotEmpty;
  } on FormatException {
    return false;
  }
}

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

/// One encrypted record binds the account, school, password verifier and
/// Android Keystore public-key fingerprint to this installation.
class LaminOfflineCredentialStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int _iterations = 60000;
  static const String _identityKey = 'lamin.offline.identity.v3';
  final LaminDeviceIdentityService _deviceIdentity =
      LaminDeviceIdentityService();

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

  String _bindingChallenge(Map<String, dynamic> payload) => jsonEncode({
    'format': 'lamin-offline-device-binding-v1',
    'version': payload['version'],
    'user_id': payload['user_id'],
    'school_id': payload['school_id'],
    'school_code': payload['school_code'],
    'username': payload['username'],
    'profile_active': payload['profile_active'],
    'must_change_password': payload['must_change_password'],
    'school_active': payload['school_active'],
    'licensed': payload['licensed'],
    'trial_started_at': payload['trial_started_at'],
    'salt': payload['salt'],
    'verifier': payload['verifier'],
    'iterations': payload['iterations'],
    'device_id': payload['device_id'],
    'device_public_key': payload['device_public_key'],
  });

  Future<Map<String, dynamic>?> readIdentity() async {
    try {
      final raw = await _storage.read(key: _identityKey);
      if (raw == null) return null;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final deviceId = saved['device_id'];
      if (saved['version'] != 3 ||
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
          saved['licensed'] is! bool ||
          deviceId is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(deviceId) ||
          saved['device_public_key'] is! String ||
          (saved['device_public_key'] as String).isEmpty ||
          saved['device_signature'] is! String ||
          (saved['device_signature'] as String).isEmpty ||
          saved['device_hardware_backed'] is! bool) {
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

    // This key is created once in Android Keystore and is never exportable.
    final device = await _deviceIdentity.getOrCreate();
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final verifier = await _derive(password, salt);
    final payload = <String, dynamic>{
      'version': 3,
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
      'device_id': device.deviceId,
      'device_public_key': device.publicKey,
      'device_hardware_backed': device.hardwareBacked,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    };

    final challenge = _bindingChallenge(payload);
    final signature = await _deviceIdentity.signChallenge(challenge);
    final currentDevice = await _deviceIdentity.getExisting();
    if (currentDevice == null ||
        currentDevice.deviceId != device.deviceId ||
        currentDevice.publicKey != device.publicKey) {
      throw StateError('Android device key changed during local enrollment.');
    }
    payload['device_signature'] = signature;

    await _storage.write(key: _identityKey, value: jsonEncode(payload));
    final persisted = await readIdentity();
    if (persisted == null ||
        persisted['user_id'] != userId ||
        persisted['school_id'] != schoolId ||
        persisted['school_code'] != schoolCode.trim().toLowerCase() ||
        persisted['username'] != username.trim().toLowerCase() ||
        persisted['device_id'] != device.deviceId) {
      throw StateError('Device-bound offline identity did not persist correctly.');
    }
  }

  Future<bool> _isBoundToCurrentDevice(Map<String, dynamic> saved) async {
    try {
      final current = await _deviceIdentity.getExisting();
      if (current == null ||
          current.deviceId != saved['device_id'] ||
          current.publicKey != saved['device_public_key']) {
        return false;
      }
      final valid = await _deviceIdentity.verifyBinding(
        challenge: _bindingChallenge(saved),
        signature: saved['device_signature'].toString(),
        deviceId: saved['device_id'].toString(),
        publicKey: saved['device_public_key'].toString(),
      );
      return valid;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyDeviceBinding() async {
    final saved = await readIdentity();
    if (saved == null) return false;
    return _isBoundToCurrentDevice(saved);
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

      // Require the original Android Keystore private key before accepting
      // the PBKDF2 password verifier.
      if (!await _isBoundToCurrentDevice(saved)) return false;

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
    if (saved == null ||
        saved['user_id'] != userId ||
        saved['school_code'] != schoolCode.trim().toLowerCase() ||
        saved['username'] != username.trim().toLowerCase()) {
      return false;
    }
    return _isBoundToCurrentDevice(saved);
  }

  Future<void> remove(String userId) async {
    final saved = await readIdentity();
    if (saved?['user_id'] == userId) {
      await _storage.delete(key: _identityKey);
    }
    await _storage.delete(key: 'lamin.offline.credential.v1.$userId');
    await _storage.delete(key: 'lamin.offline.credential.v1');
    await _storage.delete(key: 'lamin.offline.identity.v2');
  }
}
