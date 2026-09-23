import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/models/app_models.dart';
import '../core/repositories/school_repository.dart';

class TeacherProvider extends ChangeNotifier {
  final SchoolRepository repo;
  final _uuid = const Uuid();

  List<Student> students = [];
  final Map<String, bool> attendance = {};
  bool loading = false;
  String? message;

  TeacherProvider(this.repo);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    students = await repo.getTeacherStudents();
    loading = false;
    notifyListeners();
  }

  void setPresent(String studentId, bool present) {
    attendance[studentId] = present;
    notifyListeners();
  }

  Future<void> saveAttendance() async {
    final date = DateTime.now().toIso8601String();
    for (final student in students) {
      await repo.queueAttendance(
        AttendanceEntry(
          id: _uuid.v4(),
          studentId: student.id,
          date: date,
          present: attendance[student.id] ?? true,
        ),
      );
    }
    message = 'تم حفظ الحضور محلياً ومزامنة المتاح.';
    notifyListeners();
  }
}
