import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../network/api_client.dart';
import '../storage/local_store.dart';

class SchoolRepository {
  final ApiClient api;
  final LocalStore local;
  final _uuid = const Uuid();

  SchoolRepository(this.api, this.local);

  Future<AppUser> login(String username, String password, UserRole role) async {
    try {
      final response = await api.dio.post('/auth/login', data: {
        'username': username,
        'password': password,
        'role': role == UserRole.teacher ? 'teacher' : 'parent',
      });
      final data = Map<String, dynamic>.from(response.data);
      await local.saveSession(data);
      return AppUser.fromJson(data['user']);
    } on DioException {
      // Development fallback is deliberately isolated here.
      // Remove this block when the NestJS authentication endpoint is live.
      final demo = {
        'id': 'demo-user',
        'name': role == UserRole.teacher ? 'معلم تجريبي' : 'ولي أمر تجريبي',
        'role': role == UserRole.teacher ? 'teacher' : 'parent',
        'school_id': 'demo-school',
      };
      await local.saveSession({'user': demo, 'access_token': 'demo'});
      return AppUser.fromJson(demo);
    }
  }

  Future<List<Student>> getTeacherStudents() async {
    try {
      final response = await api.dio.get('/teacher/students');
      final items = List<Map<String, dynamic>>.from(response.data['items']);
      final students = items.map(Student.fromJson).toList();
      await local.saveStudents(students);
      return students;
    } catch (_) {
      return local.getStudents();
    }
  }

  Future<void> queueAttendance(AttendanceEntry entry) async {
    await local.queueAttendance(entry);
    await syncPendingAttendance();
  }

  Future<void> syncPendingAttendance() async {
    final pending = local.pendingAttendance();
    final remaining = <AttendanceEntry>[];

    for (final item in pending) {
      try {
        await api.dio.post('/attendance/sync', data: item.toJson());
        item.synced = true;
      } catch (_) {
        remaining.add(item);
      }
    }

    await local.replaceAttendanceQueue(remaining);
  }

  Future<void> submitGrade(GradeEntry grade) async {
    try {
      await api.dio.post('/grades', data: grade.toJson());
    } catch (_) {
      await local.queueAttendance(
        AttendanceEntry(
          id: grade.id,
          studentId: grade.studentId,
          date: DateTime.now().toIso8601String(),
          present: true,
          note: 'OFFLINE_GRADE:${grade.subjectId}:${grade.score}',
        ),
      );
    }
  }

  Future<List<Student>> getParentChildren() async {
    try {
      final response = await api.dio.get('/parent/children');
      final items = List<Map<String, dynamic>>.from(response.data['items']);
      return items.map(Student.fromJson).toList();
    } catch (_) {
      return local.getStudents();
    }
  }

  Future<List<InvoiceSummary>> getInvoices(String studentId) async {
    try {
      final response = await api.dio.get('/parent/students/$studentId/invoices');
      final items = List<Map<String, dynamic>>.from(response.data['items']);
      return items.map(InvoiceSummary.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<int>> downloadReceiptPdf(String invoiceId) async {
    final response = await api.dio.get<List<int>>(
      '/invoices/$invoiceId/receipt.pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

  Future<void> logout() => local.clearSession();
}
