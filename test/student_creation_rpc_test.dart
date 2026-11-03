import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/student_creation_rpc.dart';

void main() {
  group('student creation RPC contract', () {
    test('sends the exact idempotent SQL parameter names including class name', () {
      expect(
        buildStudentCreationRpcParams(
          operationId: 'offline-op-1',
          name: ' طالب اختبار ',
          className: ' الصف الأول ',
          phone: '0910000000',
          termFee: 125,
          term: 'الفصل الثاني',
        ),
        {
          'p_operation_id': 'offline-op-1',
          'p_name': 'طالب اختبار',
          'p_class_name': 'الصف الأول',
          'p_phone': '0910000000',
          'p_term_fee': 125,
          'p_term': 'الفصل الثاني',
        },
      );
    });

    test('recognizes a missing RPC schema-cache response for local queuing', () {
      final error = Exception(
        'PostgrestException: Could not find the function '
        'public.create_student_with_fee_idempotent in the schema cache '
        '(code: PGRST202)',
      );

      expect(isMissingStudentCreationRpc(error), isTrue);
    });

    test('recognizes PGRST202 even if the server omits descriptive text', () {
      expect(
        isMissingStudentCreationRpc(
          Exception(
            'PostgrestException: public.create_student_with_fee_idempotent '
            '(code: PGRST202)',
          ),
        ),
        isTrue,
      );
    });

    test('recognizes an undefined PostgreSQL function response', () {
      final error = Exception(
        'function public.create_student_with_fee_idempotent does not exist '
        '(SQLSTATE 42883)',
      );

      expect(isMissingStudentCreationRpc(error), isTrue);
    });

    test('does not convert permission or validation errors into local fallback', () {
      expect(
        isMissingStudentCreationRpc(
          Exception('permission denied for function (code: 42501)'),
        ),
        isFalse,
      );
      expect(
        isMissingStudentCreationRpc(
          Exception('student class name is required'),
        ),
        isFalse,
      );
    });
  });
}
