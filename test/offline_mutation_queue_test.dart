import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'offline student edits update the cache and replace older queued edits',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'students_cache_school-1',
        jsonEncode([
          {
            'id': 'student-1',
            'name': 'الاسم القديم',
            'class_name': 'الأول',
            'phone': '091',
          },
        ]),
      );
      final repository = SchoolRepository(prefs);

      await repository.queueOfflineStudentUpdate(
        schoolId: 'school-1',
        studentId: 'student-1',
        name: 'اسم مؤقت',
        className: 'الثاني',
        phone: '092',
      );
      await repository.queueOfflineStudentUpdate(
        schoolId: 'school-1',
        studentId: 'student-1',
        name: 'الاسم النهائي',
        className: 'الثالث',
        phone: '093',
      );

      final cache =
          jsonDecode(prefs.getString('students_cache_school-1')!) as List;
      final queue =
          jsonDecode(prefs.getString('lamin_offline_student_updates_school-1')!)
              as List;
      expect(cache.single['name'], 'الاسم النهائي');
      expect(cache.single['class_name'], 'الثالث');
      expect(queue, hasLength(1));
      expect(queue.single['name'], 'الاسم النهائي');
    },
  );

  test(
    'offline fee edits are queued by student, term and academic year',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SchoolRepository(prefs);

      await repository.queueOfflineFeeAssessment(
        schoolId: 'school-1',
        studentId: 'student-1',
        term: 'الفصل الأول',
        totalFee: 1000,
        discount: 100,
        academicYearId: 'year-1',
        academicYearLabel: '2026-2027',
      );
      await repository.queueOfflineFeeAssessment(
        schoolId: 'school-1',
        studentId: 'student-1',
        term: 'الفصل الأول',
        totalFee: 1200,
        discount: 200,
        academicYearId: 'year-1',
        academicYearLabel: '2026-2027',
      );
      await repository.queueOfflineFeeAssessment(
        schoolId: 'school-1',
        studentId: 'student-1',
        term: 'الفصل الثاني',
        totalFee: 800,
        discount: 0,
        academicYearId: 'year-1',
        academicYearLabel: '2026-2027',
      );

      final queue =
          jsonDecode(prefs.getString('lamin_offline_fee_updates_school-1')!)
              as List;
      expect(queue, hasLength(2));
      expect(queue.first['total_fee'], 1200);
      expect(queue.last['term'], 'الفصل الثاني');
    },
  );

  test('offline fee queue rejects invalid discount values', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = SchoolRepository(prefs);

    expect(
      () => repository.queueOfflineFeeAssessment(
        schoolId: 'school-1',
        studentId: 'student-1',
        term: 'الفصل الأول',
        totalFee: 100,
        discount: 101,
        academicYearLabel: '2026-2027',
      ),
      throwsException,
    );
    expect(prefs.getString('lamin_offline_fee_updates_school-1'), isNull);
  });
}
