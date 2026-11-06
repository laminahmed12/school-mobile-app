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
        isTrue,
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
}
