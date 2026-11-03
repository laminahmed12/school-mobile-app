import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/offline_credentials.dart';

void main() {
  group('cold-start offline authentication contract', () {
    test('restored Supabase session requires local credential proof', () {
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

    test('verified offline access closes login form even with restored session', () {
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
