import 'dart:convert';

import 'package:flutter/services.dart';

class LaminDeviceIdentity {
  final String deviceId;
  final String publicKey;
  final bool hardwareBacked;

  const LaminDeviceIdentity({
    required this.deviceId,
    required this.publicKey,
    required this.hardwareBacked,
  });

  factory LaminDeviceIdentity.fromMap(Map<String, dynamic> map) {
    final deviceId = map['device_id']?.toString() ?? '';
    final publicKey = map['public_key']?.toString() ?? '';
    final validFingerprint = deviceId.length == 64 &&
        deviceId.codeUnits.every(
          (value) =>
              (value >= 48 && value <= 57) ||
              (value >= 97 && value <= 102),
        );
    if (!validFingerprint || publicKey.isEmpty) {
      throw const FormatException('Invalid Android device identity response.');
    }
    return LaminDeviceIdentity(
      deviceId: deviceId,
      publicKey: publicKey,
      hardwareBacked: map['hardware_backed'] == true,
    );
  }

  String get displayId => deviceId.substring(0, 16).toUpperCase();
}

/// Device identity is backed by a non-exportable EC private key in Android
/// Keystore. The public fingerprint is an identifier, not an authenticator.
class LaminDeviceIdentityService {
  static const MethodChannel _channel =
      MethodChannel('com.adreemk.lamin/device_identity');

  Future<LaminDeviceIdentity> getOrCreate() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getOrCreateIdentity',
    );
    if (result == null) {
      throw StateError('Android Keystore did not return a device identity.');
    }
    return LaminDeviceIdentity.fromMap(result);
  }

  Future<LaminDeviceIdentity?> getExisting() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getExistingIdentity',
    );
    return result == null ? null : LaminDeviceIdentity.fromMap(result);
  }

  Future<String> signChallenge(String challenge) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'signChallenge',
      {'challenge': base64Encode(utf8.encode(challenge))},
    );
    final signature = result?['signature']?.toString() ?? '';
    if (signature.isEmpty) {
      throw StateError('Android Keystore could not prove device ownership.');
    }
    return signature;
  }

  Future<bool> verifyBinding({
    required String challenge,
    required String signature,
    required String deviceId,
    required String publicKey,
  }) async {
    return await _channel.invokeMethod<bool>(
          'verifyBinding',
          {
            'challenge': base64Encode(utf8.encode(challenge)),
            'signature': signature,
            'device_id': deviceId,
            'public_key': publicKey,
          },
        ) ??
        false;
  }
}
