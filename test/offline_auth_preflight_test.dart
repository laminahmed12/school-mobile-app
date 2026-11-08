import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/offline_credentials.dart';
import 'package:lamin_school/repository.dart';

void main() {
  group('pending offline synchronization authentication gate', () {
    test('requests online login when internet exists but no Supabase session', () {
      expect(
        shouldPromptOnlineLoginForPendingSync(
          hasInternet: true,
          hasAuthenticatedSession: false,
          pendingCount: 1,
        ),
        isTrue,
      );
    });

    test('does not request login when queue is empty or session exists', () {
      expect(
        shouldPromptOnlineLoginForPendingSync(
          hasInternet: true,
          hasAuthenticatedSession: false,
          pendingCount: 0,
        ),
        isFalse,
      );
      expect(
        shouldPromptOnlineLoginForPendingSync(
          hasInternet: true,
          hasAuthenticatedSession: true,
          pendingCount: 1,
        ),
        isFalse,
      );
      expect(
        shouldPromptOnlineLoginForPendingSync(
          hasInternet: false,
          hasAuthenticatedSession: false,
          pendingCount: 1,
        ),
        isFalse,
      );
    });
  });

  group('cold-start offline authentication contract', () {
    test('restored Supabase session still requires explicit identity proof', () {
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
    });

    test('cached profile does not bypass offline password proof', () {
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
    });

    test('online authentication keeps existing session behavior', () {
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
  });
  group('cached offline account eligibility', () {
    test('allows a previously authenticated, active, licensed account', () {
      expect(canOpenCachedOfflineAccount(
        hasRememberedUser: true,
        profileActive: true,
        hasSchoolId: true,
        isOwner: false,
        mustChangePassword: false,
        schoolActive: true,
        licensed: true,
        trialValid: false,
      ), isTrue);
    });

    test('rejects missing identity, inactive school, or expired license', () {
      expect(canOpenCachedOfflineAccount(
        hasRememberedUser: false,
        profileActive: true,
        hasSchoolId: true,
        isOwner: false,
        mustChangePassword: false,
        schoolActive: true,
        licensed: true,
        trialValid: false,
      ), isFalse);
      expect(canOpenCachedOfflineAccount(
        hasRememberedUser: true,
        profileActive: true,
        hasSchoolId: true,
        isOwner: false,
        mustChangePassword: false,
        schoolActive: false,
        licensed: true,
        trialValid: false,
      ), isFalse);
      expect(canOpenCachedOfflineAccount(
        hasRememberedUser: true,
        profileActive: true,
        hasSchoolId: true,
        isOwner: false,
        mustChangePassword: false,
        schoolActive: true,
        licensed: false,
        trialValid: false,
      ), isFalse);
    });
  });


  group('offline identity record validation', () {
    test('rejects missing or unsupported identity records', () {
      expect(isValidLaminOfflineIdentityRecord({}), isFalse);
      expect(isValidLaminOfflineIdentityRecord({'version': 2}), isFalse);
    });

    test('rejects V3 records with malformed device identity fields', () {
      expect(
        isValidLaminOfflineIdentityRecord({
          'version': 3,
          'user_id': 'user',
          'school_id': 'school',
          'school_code': 'test',
          'username': 'admin',
          'role': 'admin',
          'profile_active': true,
          'must_change_password': false,
          'school_active': true,
          'licensed': true,
          'iterations': laminOfflinePbkdf2Iterations,
          'salt': 'AAAAAAAAAAAAAAAAAAAAAA==',
          'verifier': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          'device_id': 'not-a-fingerprint',
          'device_public_key': 'key',
          'device_signature': 'signature',
          'device_hardware_backed': false,
        }),
        isFalse,
      );
    });
  });

}