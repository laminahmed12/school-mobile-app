import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline page displays the last cached school and students', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'lamin_last_profile_cache': jsonEncode({
        'username': 'مدير المدرسة',
        'role': 'admin',
        'active': true,
        'must_change_password': false,
        'school_id': 'school-1',
      }),
      'students_cache_school-1': jsonEncode([
        {
          'id': 'student-1',
          'name': 'طالب تجريبي',
          'class_name': 'الصف الأول',
          'phone': '',
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MaterialApp(home: OfflineHomePage(prefs: prefs)));

    expect(find.text('وضع العمل المحلي'), findsOneWidget);
    expect(find.text('دون اتصال'), findsOneWidget);
    expect(find.text('طالب تجريبي'), findsNothing);
    expect(
      find.text('بيانات الطلاب مخفية. اكتب في البحث لعرض النتائج المحفوظة.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'طالب تجريبي');
    await tester.pump();

    expect(find.text('طالب تجريبي'), findsNWidgets(2));
    expect(find.text('الصف الأول'), findsOneWidget);
  });
}
