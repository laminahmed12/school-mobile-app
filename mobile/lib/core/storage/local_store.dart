import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/app_models.dart';

class LocalStore {
  static const _boxName = 'school_local';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  Future<void> saveSession(Map<String, dynamic> session) async {
    await _box.put('session', session);
  }

  Map<String, dynamic>? getSession() {
    final value = _box.get('session');
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<void> clearSession() => _box.delete('session');

  Future<void> queueAttendance(AttendanceEntry entry) async {
    final list = List<Map<String, dynamic>>.from(
      (_box.get('attendance_queue') as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
    list.add(entry.toJson());
    await _box.put('attendance_queue', list);
  }

  List<AttendanceEntry> pendingAttendance() {
    return List<Map<String, dynamic>>.from(
      (_box.get('attendance_queue') as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    ).map(AttendanceEntry.fromJson).toList();
  }

  Future<void> replaceAttendanceQueue(List<AttendanceEntry> entries) async {
    await _box.put('attendance_queue', entries.map((e) => e.toJson()).toList());
  }

  Future<void> saveStudents(List<Student> students) async {
    await _box.put('students', students.map((e) => {
      'id': e.id, 'name': e.name, 'class_name': e.className
    }).toList());
  }

  List<Student> getStudents() {
    return List<Map<String, dynamic>>.from(
      (_box.get('students') as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    ).map(Student.fromJson).toList();
  }
}
