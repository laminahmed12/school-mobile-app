import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/trial_policy.dart';

void main() {
  group('schoolTrialEnd', () {
    test('uses exactly 30 days across month boundaries', () {
      final end = schoolTrialEnd({'trial_started_at': '2026-01-31T12:00:00Z'});
      expect(end, DateTime.utc(2026, 3, 2, 12));
    });

    test('uses exactly 30 days across leap day', () {
      final end = schoolTrialEnd({'trial_started_at': '2028-02-01T09:30:00Z'});
      expect(end, DateTime.utc(2028, 3, 2, 9, 30));
    });

    test('returns null for missing or invalid start date', () {
      expect(schoolTrialEnd(null), isNull);
      expect(schoolTrialEnd({}), isNull);
      expect(schoolTrialEnd({'trial_started_at': 'not-a-date'}), isNull);
    });
  });
}
