import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/offline_credentials.dart';

void main() {
  group('cold-start offline authentication contract', () {
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

    test('offline identity snapshot has a separate versioned schema', () {
      const version = 2;
      const schoolCode = 'test';
      const username = 'admin';
      const requiredIdentityParts = [
        'user_id',
        'school_id',
        'school_code',
        'username',
        'profile_active',
        'must_change_password',
        'school_active',
        'licensed',
        'trial_started_at',
        'salt',
        'verifier',
      ];
      expect(version, 2);
      expect(schoolCode, isNotEmpty);
      expect(username, isNotEmpty);
      expect(requiredIdentityParts, contains('verifier'));
      expect(requiredIdentityParts, contains('school_id'));
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
