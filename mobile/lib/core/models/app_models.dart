enum UserRole { teacher, parent }

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String schoolId;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.schoolId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        role: j['role'] == 'teacher' ? UserRole.teacher : UserRole.parent,
        schoolId: j['school_id']?.toString() ?? '',
      );
}

class Student {
  final String id;
  final String name;
  final String className;

  const Student({required this.id, required this.name, required this.className});

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        className: j['class_name']?.toString() ?? '',
      );
}

class AttendanceEntry {
  final String id;
  final String studentId;
  final String date;
  final bool present;
  final String? note;
  bool synced;

  AttendanceEntry({
    required this.id,
    required this.studentId,
    required this.date,
    required this.present,
    this.note,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'date': date,
        'present': present,
        'note': note,
        'synced': synced,
      };

  factory AttendanceEntry.fromJson(Map<String, dynamic> j) => AttendanceEntry(
        id: j['id'],
        studentId: j['student_id'],
        date: j['date'],
        present: j['present'] == true,
        note: j['note'],
        synced: j['synced'] == true,
      );
}

class GradeEntry {
  final String id;
  final String studentId;
  final String subjectId;
  final double score;
  bool synced;

  GradeEntry({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.score,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'subject_id': subjectId,
        'score': score,
        'synced': synced,
      };
}

class InvoiceSummary {
  final String id;
  final String number;
  final double total;
  final double paid;
  final double balance;
  final String status;

  const InvoiceSummary({
    required this.id,
    required this.number,
    required this.total,
    required this.paid,
    required this.balance,
    required this.status,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> j) => InvoiceSummary(
        id: j['id'].toString(),
        number: j['invoice_number']?.toString() ?? '',
        total: (j['total_amount'] as num?)?.toDouble() ?? 0,
        paid: (j['paid_amount'] as num?)?.toDouble() ?? 0,
        balance: (j['balance_due'] as num?)?.toDouble() ?? 0,
        status: j['status']?.toString() ?? '',
      );
}
