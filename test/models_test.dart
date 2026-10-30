import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/models.dart';

void main() {
  group('Student.fromMap', () {
    test('maps database fields', () {
      final student = Student.fromMap({
        'id': 'student-1',
        'name': 'أحمد',
        'class_name': 'الصف الأول',
        'phone': '0912345678',
      });
      expect(student.id, 'student-1');
      expect(student.name, 'أحمد');
      expect(student.className, 'الصف الأول');
      expect(student.phone, '0912345678');
    });

    test('uses safe defaults for missing values', () {
      final student = Student.fromMap(<String, dynamic>{});
      expect(student.id, isEmpty);
      expect(student.name, isEmpty);
      expect(student.className, isEmpty);
      expect(student.phone, isEmpty);
    });
  });

  group('SchoolProfile.fromMap', () {
    test('preserves inactive and password-change flags', () {
      final profile = SchoolProfile.fromMap({
        'school_id': 'school-1',
        'username': 'admin',
        'role': 'admin',
        'active': false,
        'must_change_password': true,
      });
      expect(profile.schoolId, 'school-1');
      expect(profile.active, isFalse);
      expect(profile.mustChangePassword, isTrue);
    });

    test('uses safe defaults for absent flags', () {
      final profile = SchoolProfile.fromMap({
        'username': 'staff',
        'role': 'teacher',
      });
      expect(profile.active, isTrue);
      expect(profile.mustChangePassword, isFalse);
      expect(profile.schoolId, isNull);
    });
  });

  group('AttendanceRecord.fromMap', () {
    test('maps status and late minutes', () {
      final record = AttendanceRecord.fromMap({
        'student_id': 'student-2',
        'status': 'late',
        'minutes_late': 12.8,
      });
      expect(record.studentId, 'student-2');
      expect(record.status, 'late');
      expect(record.minutesLate, 12);
    });

    test('defaults safely when values are absent', () {
      final record = AttendanceRecord.fromMap(<String, dynamic>{});
      expect(record.studentId, isEmpty);
      expect(record.status, 'present');
      expect(record.minutesLate, 0);
    });
  });

  group('ResultItem.fromMap', () {
    test('converts numeric scores to doubles', () {
      final result = ResultItem.fromMap({
        'id': 'result-1',
        'student_id': 'student-1',
        'term': 'الفصل الأول',
        'exam_name': 'الاختبار',
        'score': 17,
        'max_score': 20,
      });
      expect(result.score, 17.0);
      expect(result.maxScore, 20.0);
    });

    test('uses documented defaults', () {
      final result = ResultItem.fromMap(<String, dynamic>{});
      expect(result.score, 0.0);
      expect(result.maxScore, 100.0);
      expect(result.percentage, 0.0);
    });

    test('returns zero percentage when maximum score is zero', () {
      const result = ResultItem(
        id: 'result-zero',
        studentId: 'student-1',
        term: 'الفصل الأول',
        examName: 'اختبار',
        score: 0,
        maxScore: 0,
      );
      expect(result.percentage, 0.0);
    });

    test('calculates percentage for valid scores', () {
      const result = ResultItem(
        id: 'result-valid',
        studentId: 'student-1',
        term: 'الفصل الأول',
        examName: 'اختبار',
        score: 15,
        maxScore: 20,
      );
      expect(result.percentage, 75.0);
    });
  });
}
