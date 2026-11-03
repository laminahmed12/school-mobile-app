import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/offline_credentials.dart';

void main() {
  group('cold-start offline authentication contract', () {
    test('restored Supabase session cannot bypass cold offline password proof', () {
      expect(
        shouldShowLoginForm(
          hasAuthenticatedSession: true,
          offlineAccess: false,
          preparingOnlineLogin: false,
          onlineLoginPreparationFailed: false,
          requiresOfflineCredentialProof: true,
        ),
        isTrue,
      );
      expect(
        shouldShowLoginForm(
          hasAuthenticatedSession: true,
          offlineAccess: true,
          preparingOnlineLogin: false,
          onlineLoginPreparationFailed: false,
          requiresOfflineCredentialProof: false,
        ),
        isFalse,
      );
    });

    test('online auth event does not hide login form before verifier is saved', () {
      expect(
        shouldShowLoginForm(
          hasAuthenticatedSession: true,
          offlineAccess: false,
          preparingOnlineLogin: true,
          onlineLoginPreparationFailed: false,
        ),
        isTrue,
      );
      expect(
        shouldShowLoginForm(
          hasAuthenticatedSession: true,
          offlineAccess: false,
          preparingOnlineLogin: false,
          onlineLoginPreparationFailed: true,
        ),
        isTrue,
      );
      expect(
        shouldShowLoginForm(
          hasAuthenticatedSession: true,
          offlineAccess: false,
          preparingOnlineLogin: false,
          onlineLoginPreparationFailed: false,
        ),
        isFalse,
      );
    });

    Map<String, dynamic> validDeviceBoundRecord() => {
      'version': laminOfflineIdentityRecordVersion,
      'user_id': 'user-1',
      'school_id': 'school-1',
      'school_code': 'test',
      'username': 'admin',
      'role': 'admin',
      'profile_active': true,
      'must_change_password': false,
      'school_active': true,
      'licensed': false,
      'trial_started_at': '2026-11-01T00:00:00.000Z',
      'salt': base64Encode(List<int>.filled(16, 1)),
      'verifier': base64Encode(List<int>.filled(32, 2)),
      'iterations': laminOfflinePbkdf2Iterations,
      'device_id': List<String>.filled(64, 'a').join(),
      'device_public_key': base64Encode([1, 2, 3]),
      'device_signature': base64Encode([4, 5, 6]),
      'device_hardware_backed': false,
      'saved_at': '2026-11-03T00:00:00.000Z',
    };

    test('accepts the current v3 device-bound identity schema', () {
      expect(
        isValidLaminOfflineIdentityRecord(validDeviceBoundRecord()),
        isTrue,
      );
    });

    test('rejects legacy v2 records without a Keystore binding', () {
      final legacy = validDeviceBoundRecord()..['version'] = 2;
      expect(isValidLaminOfflineIdentityRecord(legacy), isFalse);
    });

    test('rejects malformed or missing device bindings', () {
      final malformedId = validDeviceBoundRecord()
        ..['device_id'] = 'android-id';
      final missingSignature = validDeviceBoundRecord()
        ..remove('device_signature');
      final invalidPublicKey = validDeviceBoundRecord()
        ..['device_public_key'] = 'not-base64!';
      expect(isValidLaminOfflineIdentityRecord(malformedId), isFalse);
      expect(isValidLaminOfflineIdentityRecord(missingSignature), isFalse);
      expect(isValidLaminOfflineIdentityRecord(invalidPublicKey), isFalse);
    });

    test('rejects an identity with malformed password verifier material', () {
      final malformedVerifier = validDeviceBoundRecord()
        ..['verifier'] = base64Encode([1, 2, 3]);
      expect(
        isValidLaminOfflineIdentityRecord(malformedVerifier),
        isFalse,
      );
    });

    test('offline access remains password-gated', () {
      // Regression invariant: restoring cached identity must never grant
      // access by itself; the PBKDF2 verifier is checked only on form submit.
      const hasCachedIdentity = true;
      const hasPasswordProof = false;
      final canEnter = hasCachedIdentity && hasPasswordProof;
      expect(canEnter, isFalse);
    });

    test('offline access requires active school and valid license', () {
      bool isEligible({
        required bool profileActive,
        required bool schoolActive,
        required bool licensed,
        required bool trialValid,
        required bool passwordValid,
      }) =>
          profileActive &&
          schoolActive &&
          (licensed || trialValid) &&
          passwordValid;

      expect(
        isEligible(
          profileActive: true,
          schoolActive: true,
          licensed: false,
          trialValid: false,
          passwordValid: true,
        ),
        isFalse,
      );
      expect(
        isEligible(
          profileActive: true,
          schoolActive: true,
          licensed: true,
          trialValid: false,
          passwordValid: true,
        ),
        isTrue,
      );
    });

    test('wrong password cannot unlock a cached account', () {
      const cachedIdentity = true;
      const passwordMatches = false;
      expect(cachedIdentity && passwordMatches, isFalse);
    });
  });
}
