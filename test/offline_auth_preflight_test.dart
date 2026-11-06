import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/offline_credentials.dart';

void main() {
  group('cold-start offline authentication contract', () {
    test('restored Supabase session does not require a new local enrollment', () {
      expect(
        shouldShowLoginForm(
          hasAuthenticatedSession: true,
          offlineAccess: false,
          preparingOnlineLogin: false,
          onlineLoginPreparationFailed: false,
          requiresOfflineCredentialProof: false,
        ),
        isFalse,
      );
    });

    test('cached authenticated session closes login form', () {
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

}