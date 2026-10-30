import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline student edits are persisted and coalesced per student', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SchoolRepository(prefs);

    await repo.queueOfflineStudentUpdate(
      schoolId: 'school-1',
      studentId: 'student-1',
      name: 'الاسم الأول',
      className: 'الأول أ',
      phone: '0910000000',
    );
    await repo.queueOfflineStudentUpdate(
      schoolId: 'school-1',
      studentId: 'student-1',
      name: 'الاسم الأخير',
      className: 'الأول ب',
      phone: '0920000000',
    );

    final queue = jsonDecode(
      prefs.getString('lamin_offline_student_updates_school-1')!,
    ) as List;
    expect(queue, hasLength(1));
    expect(queue.single['name'], 'الاسم الأخير');
    expect(queue.single['class_name'], 'الأول ب');
  });

  test('offline fee edits are persisted and coalesced per student, term and year', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SchoolRepository(prefs);

    await repo.queueOfflineFeeAssessment(
      schoolId: 'school-1',
      studentId: 'student-1',
      term: 'الفصل الأول',
      totalFee: 1000,
      discount: 50,
      academicYearId: 'year-1',
      academicYearLabel: '2026-2027',
    );
    await repo.queueOfflineFeeAssessment(
      schoolId: 'school-1',
      studentId: 'student-1',
      term: 'الفصل الأول',
      totalFee: 1200,
      discount: 100,
      academicYearId: 'year-1',
      academicYearLabel: '2026-2027',
    );

    final queue = jsonDecode(
      prefs.getString('lamin_offline_fee_updates_school-1')!,
    ) as List;
    expect(queue, hasLength(1));
    expect(queue.single['total_fee'], 1200);
    expect(queue.single['discount'], 100);
  });

  test('offline fee queue rejects invalid discounts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SchoolRepository(prefs);

    expect(
      () => repo.queueOfflineFeeAssessment(
        schoolId: 'school-1',
        studentId: 'student-1',
        term: 'الفصل الأول',
        totalFee: 500,
        discount: 600,
        academicYearLabel: '2026-2027',
      ),
      throwsException,
    );
  });
}
