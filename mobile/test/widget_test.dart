import 'package:flutter_test/flutter_test.dart';
import 'package:school_management/main.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const SchoolApp());
    await tester.pump();
    expect(find.text('نظام إدارة المدارس'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });
}
