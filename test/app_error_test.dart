import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/app_error.dart';

void main() {
  group('friendlyError', () {
    test('returns an Arabic connectivity message for socket errors', () {
      expect(
        friendlyError(const SocketException('connection failed')),
        contains('لا يمكن الاتصال بالخادم'),
      );
    });

    test('returns an Arabic timeout message for timeout errors', () {
      expect(
        friendlyError(TimeoutException('request timed out')),
        contains('انتهت مهلة الاتصال'),
      );
    });

    test('does not expose parser details for malformed server data', () {
      expect(
        friendlyError(const FormatException('unexpected token')),
        contains('استجابة غير صالحة'),
      );
    });

    test('uses the supplied fallback for empty errors', () {
      expect(friendlyError(Exception(''), fallback: 'رسالة بديلة'), 'رسالة بديلة');
    });

    test('preserves a useful non-network error message', () {
      expect(friendlyError(Exception('الطالب غير موجود')), 'الطالب غير موجود');
    });
  });
}
