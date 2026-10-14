import 'finance_summary.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'supabase_config.dart';

class SchoolRepository {
  final SharedPreferences prefs;
  SchoolRepository(this.prefs);

  Future<SchoolProfile?> profile() async {
    final u = db.auth.currentUser;
    if (u == null) return null;
    final row = await db.from('profiles').select().eq('user_id', u.id).maybeSingle();
    if (row == null) return null;
    final profile = SchoolProfile.fromMap(row);
    final schoolId = profile.schoolId;
    if (schoolId != null && schoolId.isNotEmpty) {
      // Cache tenant scope per authenticated user for offline reads only.
      await prefs.setString('school_id_cache_${u.id}', schoolId);
    }
    return profile;
  }

  Future<Map<String, dynamic>?> school() async {
    try {
      final p = await profile();
      if (p?.schoolId == null) return null;
      final row = await db.from('schools').select().eq('id', p!.schoolId!).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  Future<String?> ensureOwnerSchool({String code = 'lamin', String name = 'مدرسة لامين التجريبية'}) async {
    try {
      final p = await profile();
      if (p?.schoolId != null) return p!.schoolId;
      final result = await db.rpc('bootstrap_owner_school', params: {
        'p_code': code,
        'p_name': name,
      });
      return result?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Student>> students() async {
    // Never fall back to an unscoped cache: this device may be used by more
    // than one school account. Keep offline data separated by the signed-in
    // profile's school ID and fail closed when that scope cannot be resolved.
    final user = db.auth.currentUser;
    if (user == null) return [];
    String? schoolId;
    try {
      schoolId = (await profile())?.schoolId;
    } catch (_) {
      // profile() needs the network. On offline reads, use only the last
      // tenant ID previously fetched for this same authenticated user.
      schoolId = prefs.getString('school_id_cache_${user.id}');
    }
    if (schoolId == null || schoolId.isEmpty) return [];
    final cacheKey = 'students_cache_$schoolId';
    try {
      final rows = await db.from('students').select().order('name');
      final list = (rows as List).map((e) => Student.fromMap(Map<String, dynamic>.from(e))).toList();
      await prefs.setString(cacheKey, jsonEncode(list.map((s) => {
        'id': s.id,
        'name': s.name,
        'class_name': s.className,
        'phone': s.phone,
      }).toList()));
      return list;
    } catch (_) {
      final raw = prefs.getString(cacheKey);
      if (raw == null) return [];
      try {
        return (jsonDecode(raw) as List)
            .map((e) => Student.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        // A corrupt cache must not prevent the school from opening.
        await prefs.remove(cacheKey);
        return [];
      }
    }
  }

  Future<Map<String, dynamic>?> parent(String studentId) async {
    try {
      final row = await db.from('student_parents').select().eq('student_id', studentId).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveParent({required String studentId, required String parentName, required String phone, String relation = 'ولي الأمر'}) async {
    await db.from('student_parents').upsert({
      'student_id': studentId,
      'parent_name': parentName.trim(),
      'phone': phone.replaceAll(RegExp(r'[^0-9]'), '').trim(),
      'relation': relation.trim(),
    });
  }

  Future<Map<String, dynamic>> dailySummary(DateTime day) async {
    final d = day.toIso8601String().substring(0, 10);
    Map<String, dynamic> result = {};
    try {
      final r = await db.rpc('school_daily_summary', params: {'p_date': d});
      result = Map<String, dynamic>.from(r as Map);
    } catch (_) {}
    try {
      final start = DateTime(day.year, day.month, day.day).toUtc().toIso8601String();
      final end = DateTime(day.year, day.month, day.day + 1).toUtc().toIso8601String();
      final expenseRows = await db.from('expenses').select('amount')
          .gte('created_at', start).lt('created_at', end);
      final payrollRows = await db.from('payroll_transactions')
          .select('amount,transaction_type')
          .eq('payment_date', d);
      final expenseTotal = (expenseRows as List)
          .fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
      final payrollList = payrollRows as List;
      final salaryTotal = payrollList
          .where((row) => row['transaction_type'] == 'salary')
          .fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
      final advanceTotal = payrollList
          .where((row) => row['transaction_type'] == 'advance')
          .fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
      result['payroll_salaries'] = salaryTotal;
      result['payroll_advances'] = advanceTotal;
      result['expenses'] = expenseTotal + salaryTotal + advanceTotal;
    } catch (_) {}
    return result;
  }

  Future<List<Map<String, dynamic>>> academicYears() async {
    try {
      final schoolId = (await profile())?.schoolId;
      if (schoolId == null || schoolId.isEmpty) return [];
      return (await db.from('academic_years')
          .select()
          .eq('school_id', schoolId)
          .order('created_at', ascending: false) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> classes() async {
    try {
      final schoolId = (await profile())?.schoolId;
      if (schoolId == null || schoolId.isEmpty) return [];
      return (await db.from('classes')
          .select()
          .eq('school_id', schoolId)
          .order('name') as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addAcademicYear(String name) async {
    await db.from('academic_years').insert({'name': name.trim(), 'active': false});
  }

  Future<String?> activeAcademicYearName() async {
    try {
      final schoolId = (await profile())?.schoolId;
      if (schoolId == null || schoolId.isEmpty) return null;
      final row = await db.from('academic_years')
          .select('name')
          .eq('school_id', schoolId)
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row?['name']?.toString();
    } catch (_) { return null; }
  }

  Future<String?> createNextAcademicYear(String name, {DateTime? startsOn, DateTime? endsOn}) async {
    final result = await db.rpc('create_next_academic_year', params: {
      'p_name': name.trim(),
      'p_starts_on': startsOn?.toIso8601String().substring(0,10),
      'p_ends_on': endsOn?.toIso8601String().substring(0,10),
      'p_migrate_students': true,
      'p_migrate_staff': true,
    });
    return result?.toString();
  }

  Future<void> promoteStudent(String studentId, String? targetClassId, {String status='active'}) async {
    await db.rpc('set_student_promotion', params: {'p_student_id':studentId,'p_target_class_id':targetClassId,'p_status':status});
  }

  Future<void> addClass({required String name, String section = '', String? academicYearId, int? gradeOrder}) async {
    if (gradeOrder != null && (gradeOrder < 1 || gradeOrder > 20)) {
      throw Exception('ترتيب الصف يجب أن يكون بين 1 و20.');
    }
    var yearId = academicYearId;
    if (yearId == null || yearId.isEmpty) {
      final active = await db.from('academic_years')
          .select('id')
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      yearId = active?['id']?.toString();
    }
    await db.from('classes').insert({
      'name': name.trim(),
      'section': section.trim(),
      if (gradeOrder != null) 'grade_order': gradeOrder,
      if (yearId != null && yearId.isNotEmpty) 'academic_year_id': yearId,
    });
  }

  Future<void> addSubject(String name) async {
    await db.from('subjects').insert({'name': name.trim()});
  }

  Future<List<Teacher>> teachers() async {
    final rows = await db.from('teachers').select().order('name');
    return (rows as List).map((e) => Teacher.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SubjectItem>> subjects() async {
    try {
      final rows = await db.from('subjects').select().order('name');
      return (rows as List).map((e) => SubjectItem.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AttendanceRecord>> attendance(DateTime day) async {
    final d = day.toIso8601String().substring(0, 10);
    try {
      final rows = await db.from('attendance').select().eq('attendance_date', d);
      return (rows as List).map((e) => AttendanceRecord.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAttendance({required String studentId, required DateTime day, required String status, int minutesLate = 0}) async {
    await db.from('attendance').upsert({
      'student_id': studentId,
      'attendance_date': day.toIso8601String().substring(0, 10),
      'status': status,
      'minutes_late': minutesLate,
    });
  }

  Future<List<ResultItem>> results(String studentId) async {
    final rows = await db.from('student_results').select().eq('student_id', studentId).order('created_at', ascending: false);
    return (rows as List).map((e) => ResultItem.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> addResult({required String studentId, String? subjectId, required String term, required String exam, double score = 0, double maxScore = 100}) async {
    await db.from('student_results').insert({
      'student_id': studentId,
      'subject_id': subjectId,
      'term': term,
      'exam_name': exam,
      'score': score,
      'max_score': maxScore,
    });
  }

  Future<int> count(String table) async {
    try {
      return (await db.from(table).select('id') as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<double> paymentsTotal() async {
    try {
      return (await db.from('payments').select('amount') as List).fold<double>(0, (x, e) => x + (e['amount'] as num).toDouble());
    } catch (_) {
      return 0;
    }
  }

  Future<double> expensesTotal() async {
    double total = 0;
    try {
      total += (await db.from('expenses').select('amount') as List)
          .fold<double>(0, (x, e) => x + (e['amount'] as num).toDouble());
    } catch (_) {}
    try {
      total += (await db.from('payroll_transactions').select('amount') as List)
          .fold<double>(0, (x, e) => x + (e['amount'] as num).toDouble());
    } catch (_) {}
    return total;
  }

  Future<List<Map<String, dynamic>>> staffMembers() async {
    final rows = await db.from('staff').select('id,name,role,phone,salary,active,created_at').order('name');
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addStaffMember({required String name, required String role, required String phone, required double salary}) async {
    await db.from('staff').insert({
      'name': name.trim(),
      'role': role.trim().isEmpty ? 'موظف' : role.trim(),
      'phone': phone.trim(),
      'salary': salary,
      'active': true,
    });
  }

  Future<void> updateTeacher({
    required String teacherId,
    required String name,
    required String subject,
    required String phone,
    required double salary,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.trim().length < 2) throw Exception('أدخل اسم المعلم.');
    if (subject.trim().isEmpty) throw Exception('أدخل المادة أو التخصص.');
    if (normalizedPhone.isNotEmpty && (normalizedPhone.length < 8 || normalizedPhone.length > 15)) {
      throw Exception('رقم الهاتف يجب أن يكون من 8 إلى 15 رقمًا.');
    }
    if (salary < 0) throw Exception('الراتب لا يمكن أن يكون سالبًا.');
    await db.from('teachers').update({
      'name': name.trim(),
      'subject': subject.trim(),
      'phone': normalizedPhone,
      'salary': salary,
    }).eq('id', teacherId);
  }

  Future<void> updateStaffMember({
    required String staffId,
    required String name,
    required String role,
    required String phone,
    required double salary,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.trim().length < 2) throw Exception('أدخل اسم الموظف.');
    if (role.trim().isEmpty) throw Exception('أدخل الوظيفة.');
    if (normalizedPhone.isNotEmpty && (normalizedPhone.length < 8 || normalizedPhone.length > 15)) {
      throw Exception('رقم الهاتف يجب أن يكون من 8 إلى 15 رقمًا.');
    }
    if (salary < 0) throw Exception('الراتب لا يمكن أن يكون سالبًا.');
    await db.from('staff').update({
      'name': name.trim(),
      'role': role.trim(),
      'phone': normalizedPhone,
      'salary': salary,
    }).eq('id', staffId);
  }

  Future<void> setTeacherSalary(String teacherId, double salary) async {
    await db.from('teachers').update({'salary': salary}).eq('id', teacherId);
  }

  Future<void> setStaffSalary(String staffId, double salary) async {
    await db.from('staff').update({'salary': salary}).eq('id', staffId);
  }

  Future<List<Map<String, dynamic>>> payrollTransactions() async {
    final rows = await db.from('payroll_transactions')
        .select('id,payee_type,payee_id,transaction_type,amount,payment_date,note,created_at')
        .order('payment_date', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addPayrollTransaction({
    required String payeeType,
    required String payeeId,
    required String transactionType,
    required double amount,
    required DateTime paymentDate,
    String note = '',
  }) async {
    await db.from('payroll_transactions').insert({
      'payee_type': payeeType,
      'payee_id': payeeId,
      'transaction_type': transactionType,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().substring(0, 10),
      'note': note.trim(),
    });
  }

  Future<String> addStudent({
    required String name,
    required String className,
    required String phone,
    double termFee = 0,
    String term = 'الفصل الأول',
  }) async {
    final result = await db.rpc('create_student_with_fee', params: {
      'p_name': name.trim(),
      'p_class_name': className.trim(),
      'p_phone': phone.trim(),
      'p_term_fee': termFee,
      'p_term': term,
    });
    final id = result?.toString() ?? '';
    if (id.isEmpty) throw Exception('لم يُرجع الخادم رقم الطالب الجديد.');
    return id;
  }

  Future<void> addTeacher({
    required String name,
    required String subject,
    String phone = '',
    double salary = 0,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.trim().length < 2) throw Exception('أدخل اسم المعلم.');
    if (subject.trim().isEmpty) throw Exception('أدخل المادة التي يدرّسها.');
    if (normalizedPhone.isNotEmpty && (normalizedPhone.length < 8 || normalizedPhone.length > 15)) {
      throw Exception('رقم الهاتف يجب أن يكون من 8 إلى 15 رقمًا.');
    }
    if (salary < 0) throw Exception('الراتب لا يمكن أن يكون سالبًا.');
    await db.from('teachers').insert({
      'name': name.trim(),
      'subject': subject.trim(),
      'phone': normalizedPhone,
      'salary': salary,
    });
  }

  Future<List<Map<String, dynamic>>> studentFeeAssessments(String studentId) async {
    final schoolId = (await profile())?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية؛ أُوقف جلب الرسوم لحماية بيانات المدارس.');
    }
    final year = await db.from('academic_years')
        .select('id')
        .eq('school_id', schoolId)
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final activeYearId = year?['id']?.toString();
    final rows = await db.from('student_fee_assessments')
        .select('id,student_id,school_id,academic_year_id,academic_year_label,term,total_fee,discount,due_date,note,created_at')
        .eq('student_id', studentId)
        .order('created_at');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['academic_year_id'] == null ||
            (activeYearId != null && e['academic_year_id'].toString() == activeYearId))
        .toList();
  }

  Future<List<Map<String, dynamic>>> studentPayments(String studentId) async {
    final schoolId = (await profile())?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية؛ أُوقف جلب المدفوعات لحماية بيانات المدارس.');
    }
    final year = await db.from('academic_years')
        .select('id')
        .eq('school_id', schoolId)
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final activeYearId = year?['id']?.toString();
    final rows = await db.from('payments')
        .select('id,student_id,amount,note,created_at,payment_date,term,academic_year_id,fee_assessment_id')
        .eq('student_id', studentId)
        .order('payment_date', ascending: false);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['academic_year_id'] == null ||
            (activeYearId != null && e['academic_year_id'].toString() == activeYearId))
        .toList();
  }

  Future<Map<String, dynamic>> studentFinancialSummary(String studentId) async {
    final p = await profile();
    final schoolId = p?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية؛ أُوقف حساب المستحقات لحماية بيانات المدارس.');
    }
    final fees = await studentFeeAssessments(studentId);
    final paymentRows = await studentPayments(studentId);
    final year = await db.from('academic_years')
        .select('id,name')
        .eq('school_id', schoolId)
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final openingRows = year?['id'] == null
        ? <Map<String, dynamic>>[]
        : (await db.from('student_opening_balances')
            .select('id,amount')
            .eq('student_id', studentId)
            .eq('academic_year_id', year!['id']) as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();

    // Read the complete allocation history for this student, including reversed
    // rows, so a reversed allocation is never mistaken for a legacy unallocated payment.
    final allocationRows = (await db.from('payment_allocations')
        .select('payment_id,fee_assessment_id,opening_balance_id,amount,reversed_at')
        .eq('student_id', studentId) as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final totals = calculateStudentFinancialTotals(
      fees: fees,
      payments: paymentRows,
      openingBalances: openingRows,
      allocationRows: allocationRows,
    );

    return {
      'academic_year': year?['name']?.toString() ??
          (fees.isNotEmpty ? fees.first['academic_year_label']?.toString() : 'غير محدد'),
      'fees': totals['fees'],
      'discount': totals['discount'],
      'opening_balance': totals['opening_balance'],
      'paid': totals['paid'],
      'remaining': totals['remaining'],
      'assessments': fees,
      'payments': paymentRows,
    };
  }

  Future<void> saveStudentFeeAssessment({
    required String studentId,
    required String term,
    required double totalFee,
    double discount = 0,
    String? academicYearId,
    String academicYearLabel = 'غير محدد',
    String note = '',
  }) async {
    if (totalFee < 0 || discount < 0 || discount > totalFee) {
      throw Exception('تحقق من الرسوم والخصم؛ يجب ألا يتجاوز الخصم قيمة الرسوم.');
    }
    final p = await profile();
    final schoolId = p?.schoolId;
    if (schoolId == null || (p?.role != 'admin' && p?.role != 'owner' && p?.role != 'accountant')) {
      throw Exception('ليست لديك صلاحية تعديل الرسوم الدراسية.');
    }
    final existingForYear = academicYearId == null
        ? await db.from('student_fee_assessments')
            .select('id')
            .eq('school_id', schoolId)
            .eq('student_id', studentId)
            .eq('term', term)
            .isFilter('academic_year_id', null)
            .eq('academic_year_label', academicYearLabel)
            .maybeSingle()
        : await db.from('student_fee_assessments')
            .select('id')
            .eq('school_id', schoolId)
            .eq('student_id', studentId)
            .eq('term', term)
            .eq('academic_year_id', academicYearId)
            .maybeSingle();
    final existingUnassigned = existingForYear == null && academicYearId != null
        ? await db.from('student_fee_assessments')
            .select('id')
            .eq('school_id', schoolId)
            .eq('student_id', studentId)
            .eq('term', term)
            .isFilter('academic_year_id', null)
            .maybeSingle()
        : null;
    final existing = existingForYear ?? existingUnassigned;
    final payload = {
      'school_id': schoolId,
      'student_id': studentId,
      'academic_year_id': academicYearId,
      'academic_year_label': academicYearLabel,
      'term': term,
      'total_fee': totalFee,
      'discount': discount,
      'note': note.trim(),
      'created_by': db.auth.currentUser?.id,
    };
    if (existing?['id'] != null) {
      await db.from('student_fee_assessments').update(payload).eq('id', existing!['id']);
    } else {
      await db.from('student_fee_assessments').insert(payload);
    }
  }

  Future<void> addPayment({
    required String studentId,
    required double amount,
    String note = '',
    String term = 'غير محدد',
    String? feeAssessmentId,
    String? idempotencyKey,
  }) async {
    if (amount <= 0) throw Exception('قيمة الدفعة يجب أن تكون أكبر من صفر.');
    if (amount > 100000000) throw Exception('قيمة الدفعة أكبر من الحد المسموح.');
    final result = await db.rpc('record_student_payment', params: {
      'p_student_id': studentId,
      'p_amount': amount,
      'p_note': note.trim(),
      'p_term': term,
      'p_fee_assessment_id': feeAssessmentId == null || feeAssessmentId.isEmpty ? null : feeAssessmentId,
      'p_idempotency_key': idempotencyKey,
    });
    if (result == null || result.toString().isEmpty) {
      throw Exception('لم يؤكد الخادم تسجيل الدفعة.');
    }
  }

  Future<Map<String, dynamic>> exportBackup() async {
    // Owner backups must pass an explicit school id to the SECURITY DEFINER RPC.
    // Admin backups remain scoped by the server-side private.my_school() check.
    final p = await profile();
    if (p?.role == 'owner') {
      final schoolId = p?.schoolId;
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('تعذر تحديد المدرسة. افتح إعداد المدرسة ثم أعد محاولة النسخ الاحتياطي.');
      }
      final result = await db.rpc('export_backup', params: {'p_school': schoolId});
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'payload': result};
    }
    final result = await db.rpc('export_backup');
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'payload': result};
  }

  Future<Map<String, dynamic>> restoreBackup(Map<String, dynamic> backup) async {
    final result = await db.rpc('restore_backup', params: {'p_backup': backup});
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('استجابة استعادة النسخة غير صالحة.');
  }

  Future<Map<String, dynamic>?> schoolBranding() async {
    try {
      final p = await profile();
      if (p?.schoolId == null) return null;
      final row = await db.from('school_branding')
          .select('school_id,logo_data,logo_mime_type,updated_at')
          .eq('school_id', p!.schoolId!)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSchoolLogo({
    required String logoBase64,
    required String mimeType,
  }) async {
    final p = await profile();
    final schoolId = p?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية.');
    }
    if (p?.role != 'admin' && p?.role != 'owner') {
      throw Exception('رفع شعار المدرسة متاح لمدير المدرسة فقط.');
    }
    if (logoBase64.length > 1300000) {
      throw Exception('حجم الشعار أكبر من الحد المسموح.');
    }
    if (mimeType != 'image/png' && mimeType != 'image/jpeg') {
      throw Exception('اختر صورة PNG أو JPG.');
    }
    await db.from('school_branding').upsert({
      'school_id': schoolId,
      'logo_data': logoBase64,
      'logo_mime_type': mimeType,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> removeSchoolLogo() async {
    final p = await profile();
    final schoolId = p?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية.');
    }
    if (p?.role != 'admin' && p?.role != 'owner') {
      throw Exception('حذف شعار المدرسة متاح لمدير المدرسة فقط.');
    }
    await db.from('school_branding').delete().eq('school_id', schoolId);
  }

  Future<void> deleteSchoolUser(String userId) async {
    await db.rpc('delete_school_user', params: {'p_user_id': userId});
  }

  Future<void> grantOneDriveAccess(String userId, {required String microsoftEmail, required String microsoftAccessToken, required String driveId, required String folderItemId}) async {
    await db.functions.invoke('onedrive-access', body: {'action':'grant','user_id':userId,'microsoft_email':microsoftEmail.trim().toLowerCase(),'microsoft_access_token':microsoftAccessToken,'drive_id':driveId,'folder_item_id':folderItemId});
  }

  Future<void> revokeOneDriveAccess(String userId, {required String microsoftAccessToken, required String driveId, required String folderItemId}) async {
    await db.functions.invoke('onedrive-access', body: {'action':'revoke','user_id':userId,'microsoft_access_token':microsoftAccessToken,'drive_id':driveId,'folder_item_id':folderItemId});
  }

  Future<void> disableUserAndRevokeOneDrive(String userId, {required String microsoftAccessToken, required String driveId, required String folderItemId}) async {
    await db.functions.invoke('onedrive-access', body: {'action':'disable','user_id':userId,'microsoft_access_token':microsoftAccessToken,'drive_id':driveId,'folder_item_id':folderItemId});
  }

  Future<List<Map<String,dynamic>>> schoolUsers() async {
    final rows=await db.from('profiles').select('user_id,username,role,active,school_id,microsoft_email,onedrive_access_granted,onedrive_permission_id,onedrive_granted_at,onedrive_revoked_at').eq('school_id',(await profile())?.schoolId ?? '');
    return (rows as List).map((e)=>Map<String,dynamic>.from(e)).toList();
  }

  Future<void> addExpense({required String title, required double amount, String category = 'عام', String note = ''}) async {
    await db.from('expenses').insert({'title': title.trim(), 'amount': amount, 'category': category.trim(), 'note': note.trim()});
  }

  Future<void> queueWhatsApp({required String studentId, required String phone, required String kind, required String message}) async {
    await db.from('whatsapp_notifications').insert({'student_id': studentId, 'phone': phone, 'kind': kind, 'message': message});
  }

  Future<void> signOut() => db.auth.signOut();
}