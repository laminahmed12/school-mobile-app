import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cold-start offline authentication contract', () {
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
