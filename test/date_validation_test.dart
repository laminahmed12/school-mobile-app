import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/date_validation.dart';

void main() {
  group('isValidIsoDate', () {
    test('accepts valid dates in the required format', () {
      expect(isValidIsoDate('2026-10-13'), isTrue);
      expect(isValidIsoDate('2000-02-29'), isTrue);
      expect(isValidIsoDate('2024-04-30'), isTrue);
    });

    test('rejects impossible calendar dates', () {
      expect(isValidIsoDate('2026-02-29'), isFalse);
      expect(isValidIsoDate('2026-04-31'), isFalse);
      expect(isValidIsoDate('2026-13-01'), isFalse);
      expect(isValidIsoDate('2026-00-10'), isFalse);
      expect(isValidIsoDate('2026-01-00'), isFalse);
    });

    test('applies Gregorian leap-year rules', () {
      expect(isValidIsoDate('1900-02-29'), isFalse);
      expect(isValidIsoDate('2000-02-29'), isTrue);
      expect(isValidIsoDate('2024-02-29'), isTrue);
    });

    test('rejects malformed or padded input', () {
      expect(isValidIsoDate('26-10-13'), isFalse);
      expect(isValidIsoDate('2026/10/13'), isFalse);
      expect(isValidIsoDate(' 2026-10-13'), isFalse);
      expect(isValidIsoDate(''), isFalse);
    });
  });
}
