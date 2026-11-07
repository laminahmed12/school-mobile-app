import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/biometric_service.dart';

void main() {
  group('biometric lifecycle lock policy', () {
    test('locks authenticated app when backgrounded and preference is enabled', () {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
      ]) {
        expect(
          shouldEngageBiometricLockForLifecycle(
            state: state,
            biometricEnabled: true,
            hasAuthenticatedAccess: true,
          ),
          isTrue,
        );
      }
    });

    test('does not create another lock request on resume or inactive events', () {
      for (final state in [
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.detached,
      ]) {
        expect(
          shouldEngageBiometricLockForLifecycle(
            state: state,
            biometricEnabled: true,
            hasAuthenticatedAccess: true,
          ),
          isFalse,
        );
      }
    });

    test('does not lock when biometric preference is disabled', () {
      expect(
        shouldEngageBiometricLockForLifecycle(
          state: AppLifecycleState.paused,
          biometricEnabled: false,
          hasAuthenticatedAccess: true,
        ),
        isFalse,
      );
    });

    test('does not lock when no authenticated session is active', () {
      expect(
        shouldEngageBiometricLockForLifecycle(
          state: AppLifecycleState.hidden,
          biometricEnabled: true,
          hasAuthenticatedAccess: false,
        ),
        isFalse,
      );
    });
  });
}
