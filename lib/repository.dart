import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';
import 'supabase_config.dart';

class SchoolRepository {
  final SharedPreferences prefs;
  SchoolRepository(this.prefs);

  Future<String?> _userId() async {
    final currentUserId = db.auth.currentUser?.id;
    if (currentUserId != null && currentUserId.isNotEmpty) return currentUserId;
    return const FlutterSecureStorage().read(key: 'lamin.offline.user.id');
  }

  String _profileCacheKey(String userId) => 'lamin_profile_cache_v1_$userId';
  String _schoolCacheKey(String schoolId) => 'lamin_school_cache_v1_$schoolId';
  String _tenantCacheKey(String schoolId, String table) => 'lamin_data_cache_v1_${schoolId}_$table';

  Future<List<Map<String, dynamic>>> _cachedRows(String schoolId, String key) async {
    final raw = prefs.getString(_tenantCacheKey(schoolId, key));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      await prefs.remove(_tenantCacheKey(schoolId, key));
      return [];
    }
  }

  Future<void> _saveRows(String schoolId, String key, List rows) async {
    await prefs.setString(_tenantCacheKey(schoolId, key), jsonEncode(rows));
  }

  Future<String?> _schoolId() async {
    final userId = await _userId();
    if (userId == null) return null;
    return prefs.getString('school_id_cache_$userId') ??
        (await cachedProfile())?.schoolId;
  }

  Future<List<Map<String, dynamic>>> _readRows(
    String key,
    Future<dynamic> Function() request,
  ) async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return [];
    try {
      final result = await request().timeout(const Duration(seconds: 7));
      final rows = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      await _saveRows(schoolId, key, rows);
      return rows;
    } catch (_) {
      return _cachedRows(schoolId, key);
    }
  }


  String _newOfflineId(String prefix) {
    final random = math.Random.secure();
    final suffix = List.generate(3, (_) => random.nextInt(1 << 32).toRadixString(16)).join();
    return 'offline-$prefix-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
  String _offlineQueueKey(String schoolId) => 'lamin_offline_ops_v2_$schoolId';
  Future<List<Map<String, dynamic>>> _readOfflineOperations(String schoolId) async {
    final raw = prefs.getString(_offlineQueueKey(schoolId));
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).map((x) => Map<String,dynamic>.from(x as Map)).toList(); }
    catch (_) { return []; }
  }
  Future<void> _writeOfflineOperations(String schoolId,List<Map<String,dynamic>> rows) async {
    if(rows.isEmpty) await prefs.remove(_offlineQueueKey(schoolId));
    else await prefs.setString(_offlineQueueKey(schoolId),jsonEncode(rows));
  }
  Future<void> _queueOfflineOperation(String schoolId,Map<String,dynamic> op,{String? dedupeType,String? dedupeKey}) async {
    final rows=await _readOfflineOperations(schoolId);
    if(dedupeType!=null&&dedupeKey!=null) rows.removeWhere((x)=>x['type']==dedupeType&&x['dedupe_key']==dedupeKey);
    rows.add({'operation_id':_newOfflineId('op'),'created_at':DateTime.now().toUtc().toIso8601String(),...op,if(dedupeKey!=null)'dedupe_key':dedupeKey});
    await _writeOfflineOperations(schoolId,rows);
  }
  Future<bool> _serverAvailable() async {
    try { await db.from('schools').select('id').limit(1).timeout(const Duration(seconds:3)); return true; }
    catch (_) { return false; }
  }
  Future<List<Map<String,dynamic>>> _cachedStudentMaps(String schoolId) async {
    final raw=prefs.getString('students_cache_$schoolId');
    if(raw==null)return [];
    try{return (jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();}
    catch(_){return [];}
  }
  Future<void> _cacheStudent(String schoolId,{required String id,required String name,required String className,required String phone}) async {
    final rows=await _cachedStudentMaps(schoolId);
    final index=rows.indexWhere((x)=>x['id']?.toString()==id);
    final value={'id':id,'name':name.trim(),'class_name':className.trim(),'phone':phone.trim()};
    if(index<0)rows.insert(0,value);else rows[index]={...rows[index],...value};
    await prefs.setString('students_cache_$schoolId',jsonEncode(rows));
  }
  Future<void> updateStudent({required String studentId,required String name,required String className,required String phone}) async {
    if(name.trim().length<2||className.trim().isEmpty)throw Exception('أدخل اسم الطالب والصف بصورة صحيحة.');
    final schoolId=await _schoolId();
    if(schoolId==null||schoolId.isEmpty)throw Exception('تعذر تحديد المدرسة الحالية.');
    final cleanPhone=phone.replaceAll(RegExp(r'[^0-9+]'),'');
    final queue=await _readOfflineOperations(schoolId);
    final pendingCreate=queue.indexWhere((x)=>x['type']=='create_student'&&x['local_id']==studentId);
    if(studentId.startsWith('offline-')){
      if(pendingCreate>=0){queue[pendingCreate]={...queue[pendingCreate],'name':name.trim(),'class_name':className.trim(),'phone':cleanPhone};await _writeOfflineOperations(schoolId,queue);}
      else{await _queueOfflineOperation(schoolId,{'type':'update_student','student_id':studentId,'name':name.trim(),'class_name':className.trim(),'phone':cleanPhone},dedupeType:'update_student',dedupeKey:studentId);}
      await _cacheStudent(schoolId,id:studentId,name:name,className:className,phone:cleanPhone);return;
    }
    if(!await _serverAvailable()){
      await _queueOfflineOperation(schoolId,{'type':'update_student','student_id':studentId,'name':name.trim(),'class_name':className.trim(),'phone':cleanPhone},dedupeType:'update_student',dedupeKey:studentId);
      await _cacheStudent(schoolId,id:studentId,name:name,className:className,phone:cleanPhone);return;
    }
    await db.from('students').update({'name':name.trim(),'class_name':className.trim(),'phone':cleanPhone}).eq('id',studentId);
    await _cacheStudent(schoolId,id:studentId,name:name,className:className,phone:cleanPhone);
  }
  Future<int> syncPendingOfflineChanges() async {
    if(db.auth.currentSession==null)return 0;
    final p=await profile();final schoolId=p?.schoolId;
    if(schoolId==null||schoolId.isEmpty||!await _serverAvailable())return 0;
    final queue=await _readOfflineOperations(schoolId);if(queue.isEmpty)return 0;
    final mapKey='lamin_offline_id_map_v1_$schoolId';Map<String,dynamic> idMap={};
    try{final raw=prefs.getString(mapKey);if(raw!=null)idMap=Map<String,dynamic>.from(jsonDecode(raw));}catch(_){}
    String resolve(dynamic value){final id=value?.toString()??'';return idMap[id]?.toString()??id;}
    var synced=0;
    while(queue.isNotEmpty){
      final item=queue.first;
      try{
        final type=item['type']?.toString();
        if(type=='create_student'){
          final result=await db.rpc('create_student_with_fee',params:{'p_name':item['name'],'p_class_name':item['class_name'],'p_phone':item['phone']??'','p_term_fee':item['term_fee']??0,'p_term':item['term']??'الفصل الأول'}).timeout(const Duration(seconds:15));
          final remote=result?.toString()??'';if(remote.isEmpty)throw Exception('لم يؤكد الخادم إنشاء الطالب.');
          final local=item['local_id'].toString();idMap[local]=remote;await prefs.setString(mapKey,jsonEncode(idMap));
          final students=await _cachedStudentMaps(schoolId);final ix=students.indexWhere((x)=>x['id']?.toString()==local);
          if(ix>=0){students[ix]['id']=remote;await prefs.setString('students_cache_$schoolId',jsonEncode(students));}
        }else if(type=='update_student'){
          await db.from('students').update({'name':item['name'],'class_name':item['class_name'],'phone':item['phone']??''}).eq('id',resolve(item['student_id'])).timeout(const Duration(seconds:15));
        }else if(type=='save_fee'){
          final studentId=resolve(item['student_id']);final yearId=item['academic_year_id'];
          final payload={'school_id':schoolId,'student_id':studentId,'academic_year_id':yearId,'academic_year_label':item['academic_year_label']??'غير محدد','term':item['term'],'total_fee':item['total_fee'],'discount':item['discount']??0,'note':item['note']??'','created_by':db.auth.currentUser?.id};
          final base=db.from('student_fee_assessments').select('id').eq('school_id',schoolId).eq('student_id',studentId).eq('term',item['term']);
          final existing=yearId==null?await base.isFilter('academic_year_id',null).eq('academic_year_label',item['academic_year_label']??'غير محدد').maybeSingle():await base.eq('academic_year_id',yearId).maybeSingle();
          final saved=existing?['id']!=null
              ?await db.from('student_fee_assessments').update(payload).eq('id',existing!['id']).select('id').single()
              :await db.from('student_fee_assessments').insert(payload).select('id').single();
          final localFee=item['local_id']?.toString();final remoteFee=saved['id']?.toString();
          if(localFee!=null&&remoteFee!=null){idMap[localFee]=remoteFee;await prefs.setString(mapKey,jsonEncode(idMap));}
          final rows=await _cachedRows(schoolId,'fees_$studentId');final ix=rows.indexWhere((x)=>x['term']==item['term']&&x['academic_year_id']?.toString()==yearId?.toString());
          final cached={...payload,'id':remoteFee??localFee??''};if(ix>=0)rows[ix]=cached;else rows.add(cached);await _saveRows(schoolId,'fees_$studentId',rows);
        }else if(type=='add_payment'){
          final result=await db.rpc('record_student_payment',params:{'p_student_id':resolve(item['student_id']),'p_amount':item['amount'],'p_note':item['note']??'','p_term':item['term']??'غير محدد','p_fee_assessment_id':item['fee_assessment_id']==null?null:resolve(item['fee_assessment_id']),'p_idempotency_key':item['idempotency_key']}).timeout(const Duration(seconds:20));
          if(result==null||result.toString().isEmpty)throw Exception('لم يؤكد الخادم تسجيل الدفعة.');
          const secure=FlutterSecureStorage();final pendingKey='lamin.pending_payments.v1_$schoolId';
          try{final raw=await secure.read(key:pendingKey);if(raw!=null){final pending=Map<String,dynamic>.from(jsonDecode(raw));pending.remove(item['fingerprint']);if(pending.isEmpty)await secure.delete(key:pendingKey);else await secure.write(key:pendingKey,value:jsonEncode(pending));}}catch(_){}
        }else if(type=='attendance'){
          await db.from('attendance').upsert({'student_id':resolve(item['student_id']),'attendance_date':item['attendance_date'],'status':item['status'],'minutes_late':item['minutes_late']??0}).timeout(const Duration(seconds:15));
        }else{throw Exception('نوع عملية محلية غير معروف: $type');}
        queue.removeAt(0);await _writeOfflineOperations(schoolId,queue);synced++;
      }catch(error){debugPrint('Offline sync paused at ${item['type']}: $error');break;}
    }
    return synced;
  }

  Future<SchoolProfile?> cachedProfile() async {
    final userId = await _userId();
    if (userId == null) return null;
    final raw = prefs.getString(_profileCacheKey(userId));
    if (raw == null) return null;
    try { return SchoolProfile.fromMap(Map<String, dynamic>.from(jsonDecode(raw))); }
    catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> cachedSchool() async {
    final p = await cachedProfile();
    if (p?.schoolId == null) return null;
    final raw = prefs.getString(_schoolCacheKey(p!.schoolId!));
    if (raw == null) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) { return null; }
  }

  Future<SchoolProfile?> profile() async {
    final u = db.auth.currentUser;
    if (u == null) return cachedProfile();
    try {
      final row = await db.from('profiles').select().eq('user_id', u.id)
          .maybeSingle().timeout(const Duration(seconds: 6));
      if (row == null) return null;
      final profile = SchoolProfile.fromMap(row);
      await prefs.setString(_profileCacheKey(u.id), jsonEncode(Map<String, dynamic>.from(row)));
      final schoolId = profile.schoolId;
      if (schoolId != null && schoolId.isNotEmpty) {
        await prefs.setString('school_id_cache_${u.id}', schoolId);
      }
      return profile;
    } catch (_) {
      final raw = prefs.getString(_profileCacheKey(u.id));
      if (raw == null) return null;
      try {
        return SchoolProfile.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, dynamic>?> school() async {
    final p = await profile();
    if (p?.schoolId == null) return null;
    final id = p!.schoolId!;
    try {
      final row = await db.from('schools').select().eq('id', id)
          .maybeSingle().timeout(const Duration(seconds: 6));
      if (row == null) return null;
      final data = Map<String, dynamic>.from(row);
      await prefs.setString(_schoolCacheKey(id), jsonEncode(data));
      return data;
    } catch (_) {
      final raw = prefs.getString(_schoolCacheKey(id));
      if (raw == null) return null;
      try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) { return null; }
    }
  }

  Future<String?> ensureOwnerSchool({
    String code = 'lamin',
    String name = 'مدرسة لامين التجريبية',
  }) async {
    try {
      final p = await profile();
      if (p?.schoolId != null) return p!.schoolId;
      final result = await db.rpc(
        'bootstrap_owner_school',
        params: {'p_code': code, 'p_name': name},
      );
      return result?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Student>> students() async {
    // Never read a shared unscoped cache: devices can be used by multiple
    // school accounts. Offline data is isolated by the authenticated tenant.
    final userId = await _userId();
    if (userId == null) return [];
    String? schoolId;
    try {
      schoolId = (await profile())?.schoolId;
    } catch (_) {
      schoolId = prefs.getString('school_id_cache_${userId}');
    }
    if (schoolId == null || schoolId.isEmpty) return [];
    final cacheKey = 'students_cache_${schoolId}';
    try {
      final rows = await db.from('students').select().order('name');
      final list = (rows as List)
          .map((e) => Student.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      await prefs.setString(
        cacheKey,
        jsonEncode(
          list
              .map(
                (s) => {
                  'id': s.id,
                  'name': s.name,
                  'class_name': s.className,
                  'phone': s.phone,
                },
              )
              .toList(),
        ),
      );
      return list;
    } catch (_) {
      final raw = prefs.getString(cacheKey);
      if (raw == null) return [];
      try {
        return (jsonDecode(raw) as List)
            .map((e) => Student.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        await prefs.remove(cacheKey);
        return [];
      }
    }
  }

  Future<Map<String, dynamic>?> parent(String studentId) async {
    final schoolId = await _schoolId();
    if (schoolId == null) return null;
    final key = _tenantCacheKey(schoolId, 'parent_$studentId');
    try {
      final row = await db
          .from('student_parents')
          .select()
          .eq('student_id', studentId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (row == null) {
        await prefs.remove(key);
        return null;
      }
      final data = Map<String, dynamic>.from(row);
      await prefs.setString(key, jsonEncode(data));
      return data;
    } catch (_) {
      final raw = prefs.getString(key);
      if (raw == null) return null;
      try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {
        await prefs.remove(key);
        return null;
      }
    }
  }

  Future<void> saveParent({
    required String studentId,
    required String parentName,
    required String phone,
    String relation = 'ولي الأمر',
  }) async {
    await db.from('student_parents').upsert({
      'student_id': studentId,
      'parent_name': parentName.trim(),
      'phone': phone.replaceAll(RegExp(r'[^0-9]'), '').trim(),
      'relation': relation.trim(),
    });
  }

  Future<Map<String, dynamic>> dailySummary(DateTime day) async {
    final d = day.toIso8601String().substring(0, 10);
    final schoolId = await _schoolId();
    final cacheKey = schoolId == null ? null : _tenantCacheKey(schoolId, 'daily_summary_$d');
    Map<String, dynamic> result = {};
    try {
      final r = await db.rpc('school_daily_summary', params: {'p_date': d})
          .timeout(const Duration(seconds: 7));
      result = Map<String, dynamic>.from(r as Map);
      final start = DateTime(day.year, day.month, day.day).toUtc().toIso8601String();
      final end = DateTime(day.year, day.month, day.day + 1).toUtc().toIso8601String();
      var expenseTotal = 0.0;
      var offset = 0;
      const pageSize = 500;
      while (true) {
        final rows = await db.from('expenses').select('id,amount')
            .gte('created_at', start).lt('created_at', end)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1)
            .timeout(const Duration(seconds: 7)) as List;
        expenseTotal += rows.fold<double>(
          0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
        if (rows.length < pageSize) break;
        offset += pageSize;
      }
      var salaryTotal = 0.0;
      var advanceTotal = 0.0;
      offset = 0;
      while (true) {
        final rows = await db.from('payroll_transactions')
            .select('id,amount,transaction_type')
            .eq('payment_date', d).order('id', ascending: true)
            .range(offset, offset + pageSize - 1)
            .timeout(const Duration(seconds: 7)) as List;
        for (final row in rows) {
          final amount = (row['amount'] as num?)?.toDouble() ?? 0;
          if (row['transaction_type'] == 'salary') salaryTotal += amount;
          if (row['transaction_type'] == 'advance') advanceTotal += amount;
        }
        if (rows.length < pageSize) break;
        offset += pageSize;
      }
      result['payroll_salaries'] = salaryTotal;
      result['payroll_advances'] = advanceTotal;
      result['expenses'] = expenseTotal + salaryTotal + advanceTotal;
      if (cacheKey != null) await prefs.setString(cacheKey, jsonEncode(result));
      return result;
    } catch (_) {
      if (cacheKey == null) return result;
      final raw = prefs.getString(cacheKey);
      if (raw == null) return result;
      try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {
        await prefs.remove(cacheKey);
        return result;
      }
    }
  }

  Future<List<Map<String, dynamic>>> academicYears() => _readRows(
    'academic_years',
    () => db.from('academic_years').select().order('created_at', ascending: false),
  );

  Future<List<Map<String, dynamic>>> classes() =>
      _readRows('classes', () => db.from('classes').select().order('name'));

  Future<void> addAcademicYear(String name) async {
    await db.from('academic_years').insert({
      'name': name.trim(),
      'active': false,
    });
  }

  Future<String?> activeAcademicYearName() async {
    final schoolId = await _schoolId();
    final cacheKey = schoolId == null
        ? null
        : _tenantCacheKey(schoolId, 'active_academic_year_name');
    try {
      final row = await db
          .from('academic_years')
          .select('name')
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final name = row?['name']?.toString();
      if (cacheKey != null && name != null) {
        await prefs.setString(cacheKey, name);
      }
      return name;
    } catch (_) {
      return cacheKey == null ? null : prefs.getString(cacheKey);
    }
  }

  Future<String?> createNextAcademicYear(
    String name, {
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    final result = await db.rpc(
      'create_next_academic_year',
      params: {
        'p_name': name.trim(),
        'p_starts_on': startsOn?.toIso8601String().substring(0, 10),
        'p_ends_on': endsOn?.toIso8601String().substring(0, 10),
        'p_migrate_students': true,
        'p_migrate_staff': true,
      },
    );
    return result?.toString();
  }

  Future<void> promoteStudent(
    String studentId,
    String? targetClassId, {
    String status = 'active',
  }) async {
    await db.rpc(
      'set_student_promotion',
      params: {
        'p_student_id': studentId,
        'p_target_class_id': targetClassId,
        'p_status': status,
      },
    );
  }

  Future<void> addClass({
    required String name,
    String section = '',
    String? academicYearId,
  }) async {
    var yearId = academicYearId;
    if (yearId == null || yearId.isEmpty) {
      final active = await db
          .from('academic_years')
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
      if (yearId != null && yearId.isNotEmpty) 'academic_year_id': yearId,
    });
  }

  Future<void> addSubject(String name) async {
    await db.from('subjects').insert({'name': name.trim()});
  }

  Future<List<Teacher>> teachers() async {
    final userId = await _userId();
    final schoolId = userId == null ? null : (prefs.getString('school_id_cache_${userId}') ?? (await cachedProfile())?.schoolId);
    if (schoolId == null || schoolId.isEmpty) return [];
    try {
      final rows = await db.from('teachers').select().order('name').timeout(const Duration(seconds: 6));
      final raw = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      await _saveRows(schoolId, 'teachers', raw);
      return raw.map(Teacher.fromMap).toList();
    } catch (_) {
      return (await _cachedRows(schoolId, 'teachers')).map(Teacher.fromMap).toList();
    }
  }

  Future<List<SubjectItem>> subjects() async =>
      (await _readRows('subjects', () => db.from('subjects').select().order('name')))
          .map(SubjectItem.fromMap).toList();

  Future<List<AttendanceRecord>> attendance(DateTime day) async {
    final d = day.toIso8601String().substring(0, 10);
    return (await _readRows('attendance_$d', () =>
      db.from('attendance').select().eq('attendance_date', d)))
        .map(AttendanceRecord.fromMap).toList();
  }

  Future<void> saveAttendance({required String studentId,required DateTime day,required String status,int minutesLate=0}) async {
    final schoolId=await _schoolId();if(schoolId==null||schoolId.isEmpty)throw Exception('تعذر تحديد المدرسة الحالية.');
    final date=day.toIso8601String().substring(0,10);
    if(studentId.startsWith('offline-')||!await _serverAvailable()){
      await _queueOfflineOperation(schoolId,{'type':'attendance','student_id':studentId,'attendance_date':date,'status':status,'minutes_late':minutesLate},dedupeType:'attendance',dedupeKey:'$studentId:$date');
      final rows=await _cachedRows(schoolId,'attendance_$date');rows.removeWhere((x)=>x['student_id']?.toString()==studentId);
      rows.add({'id':_newOfflineId('attendance'),'student_id':studentId,'attendance_date':date,'status':status,'minutes_late':minutesLate});
      await _saveRows(schoolId,'attendance_$date',rows);return;
    }
    await db.from('attendance').upsert({'student_id':studentId,'attendance_date':date,'status':status,'minutes_late':minutesLate});
  }

  Future<List<ResultItem>> results(String studentId) async =>
      (await _readRows('results_$studentId', () => db.from('student_results')
        .select().eq('student_id', studentId).order('created_at', ascending: false)))
        .map(ResultItem.fromMap).toList();

  Future<void> addResult({
    required String studentId,
    String? subjectId,
    required String term,
    required String exam,
    double score = 0,
    double maxScore = 100,
  }) async {
    await db.from('student_results').insert({
      'student_id': studentId,
      'subject_id': subjectId,
      'term': term,
      'exam_name': exam,
      'score': score,
      'max_score': maxScore,
    });
  }

  Future<double> _sumColumnPaged(String table, String column) async {
    const pageSize = 500;
    var offset = 0;
    var total = 0.0;
    while (true) {
      final rows = await db.from(table).select(column)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1)
          .timeout(const Duration(seconds: 7)) as List;
      total += rows.fold<double>(
        0,
        (sum, row) => sum + ((row[column] as num?)?.toDouble() ?? 0),
      );
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return total;
  }

  Future<int> _countRowsPaged(String table) async {
    const pageSize = 500;
    var offset = 0;
    var total = 0;
    while (true) {
      final rows = await db.from(table).select('id')
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1)
          .timeout(const Duration(seconds: 7)) as List;
      total += rows.length;
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return total;
  }

  Future<int> count(String table) async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return 0;
    final cacheKey = _tenantCacheKey(schoolId, 'count_$table');
    try {
      final value = await _countRowsPaged(table);
      await prefs.setInt(cacheKey, value);
      return value;
    } catch (_) {
      return prefs.getInt(cacheKey) ?? 0;
    }
  }

  Future<double> paymentsTotal() async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return 0;
    final cacheKey = 'lamin_payments_total_${schoolId}';
    try {
      final total = await _sumColumnPaged('payments', 'amount');
      await prefs.setDouble(cacheKey, total);
      return total;
    } catch (_) {
      return prefs.getDouble(cacheKey) ?? 0;
    }
  }

  Future<double> expensesTotal() async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return 0;
    final cacheKey = 'lamin_expenses_total_${schoolId}';
    try {
      final expenseTotal = await _sumColumnPaged('expenses', 'amount');
      final payrollTotal = await _sumColumnPaged('payroll_transactions', 'amount');
      final total = expenseTotal + payrollTotal;
      await prefs.setDouble(cacheKey, total);
      return total;
    } catch (_) {
      return prefs.getDouble(cacheKey) ?? 0;
    }
  }

  Future<List<Map<String, dynamic>>> staffMembers() => _readRows(
    'staff',
    () => db.from('staff').select('id,name,role,phone,salary,active,created_at').order('name'),
  );

  Future<void> addStaffMember({
    required String name,
    required String role,
    required String phone,
    required double salary,
  }) async {
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
    if (normalizedPhone.isNotEmpty &&
        (normalizedPhone.length < 8 || normalizedPhone.length > 15)) {
      throw Exception('رقم الهاتف يجب أن يكون من 8 إلى 15 رقمًا.');
    }
    if (salary < 0) throw Exception('الراتب لا يمكن أن يكون سالبًا.');
    await db
        .from('teachers')
        .update({
          'name': name.trim(),
          'subject': subject.trim(),          'phone': normalizedPhone,
          'salary': salary,
        })        .eq('id', teacherId);
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
    if (normalizedPhone.isNotEmpty &&
        (normalizedPhone.length < 8 || normalizedPhone.length > 15)) {
      throw Exception('رقم الهاتف يجب أن يكون من 8 إلى 15 رقمًا.');
    }
    if (salary < 0) throw Exception('الراتب لا يمكن أن يكون سالبًا.');
    await db
        .from('staff')
        .update({
          'name': name.trim(),
          'role': role.trim(),
          'phone': normalizedPhone,
          'salary': salary,
        })
        .eq('id', staffId);
  }

  Future<void> setTeacherSalary(String teacherId, double salary) async {
    await db.from('teachers').update({'salary': salary}).eq('id', teacherId);
  }

  Future<void> setStaffSalary(String staffId, double salary) async {
    await db.from('staff').update({'salary': salary}).eq('id', staffId);
  }

  Future<List<Map<String, dynamic>>> payrollTransactions() => _readRows(
    'payroll_transactions',
    () => db.from('payroll_transactions')
      .select('id,payee_type,payee_id,transaction_type,amount,payment_date,note,created_at')
      .order('payment_date', ascending: false),
  );

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

  Future<String> addStudent({required String name,required String className,required String phone,double termFee=0,String term='الفصل الأول'}) async {
    if(name.trim().length<2||className.trim().isEmpty||termFee<0)throw Exception('تحقق من اسم الطالب والصف والرسوم.');
    final schoolId=await _schoolId();if(schoolId==null||schoolId.isEmpty)throw Exception('تعذر تحديد المدرسة الحالية.');
    if(!await _serverAvailable()){
      final localId=_newOfflineId('student');
      await _queueOfflineOperation(schoolId,{'type':'create_student','local_id':localId,'name':name.trim(),'class_name':className.trim(),'phone':phone.trim(),'term_fee':termFee,'term':term});
      await _cacheStudent(schoolId,id:localId,name:name,className:className,phone:phone);return localId;
    }
    final result=await db.rpc('create_student_with_fee',params:{'p_name':name.trim(),'p_class_name':className.trim(),'p_phone':phone.trim(),'p_term_fee':termFee,'p_term':term});
    final id=result?.toString()??'';if(id.isEmpty)throw Exception('لم يُرجع الخادم رقم الطالب الجديد.');
    await _cacheStudent(schoolId,id:id,name:name,className:className,phone:phone);return id;
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
    if (normalizedPhone.isNotEmpty &&
        (normalizedPhone.length < 8 || normalizedPhone.length > 15)) {
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

  Future<List<Map<String, dynamic>>> studentFeeAssessments(
    String studentId,
  ) async {
    final schoolId = await _schoolId();
    if (schoolId == null) return [];
    try {
      final year = await db.from('academic_years').select('id')
          .eq('active', true).order('created_at', ascending: false)
          .limit(1).maybeSingle().timeout(const Duration(seconds: 6));
      final activeYearId = year?['id']?.toString();
      final rows = await db.from('student_fee_assessments').select(
        'id,student_id,school_id,academic_year_id,academic_year_label,term,total_fee,discount,due_date,note,created_at',
      ).eq('student_id', studentId).order('created_at')
          .timeout(const Duration(seconds: 7));
      final result = (rows as List).map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['academic_year_id'] == null ||
              (activeYearId != null && e['academic_year_id'].toString() == activeYearId))
          .toList();
      await _saveRows(schoolId, 'fees_$studentId', result);
      return result;
    } catch (_) {
      return _cachedRows(schoolId, 'fees_$studentId');
    }
  }

  Future<List<Map<String, dynamic>>> studentPayments(String studentId) async {
    final schoolId = await _schoolId();
    if (schoolId == null) return [];
    try {
      final year = await db.from('academic_years').select('id')
          .eq('active', true).order('created_at', ascending: false)
          .limit(1).maybeSingle().timeout(const Duration(seconds: 6));
      final activeYearId = year?['id']?.toString();
      final rows = await db.from('payments').select(
        'id,student_id,amount,note,created_at,payment_date,term,academic_year_id,fee_assessment_id',
      ).eq('student_id', studentId).order('payment_date', ascending: false)
          .timeout(const Duration(seconds: 7));
      final result = (rows as List).map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['academic_year_id'] == null ||
              (activeYearId != null && e['academic_year_id'].toString() == activeYearId))
          .toList();
      await _saveRows(schoolId, 'payments_$studentId', result);
      return result;
    } catch (_) {
      return _cachedRows(schoolId, 'payments_$studentId');
    }
  }

  Future<Map<String, dynamic>> studentFinancialSummary(String studentId) async {
    final schoolId = await _schoolId();
    final cacheKey = schoolId == null ? null : _tenantCacheKey(schoolId, 'financial_summary_$studentId');
    try {
      final fees = await studentFeeAssessments(studentId);
      final paymentRows = await studentPayments(studentId);
      final year = await db.from('academic_years').select('id,name')
          .eq('active', true).order('created_at', ascending: false)
          .limit(1).maybeSingle().timeout(const Duration(seconds: 6));
      double totalFee = 0, discount = 0, paid = 0;
      for (final row in fees) {
        totalFee += (row['total_fee'] as num?)?.toDouble() ?? 0;
        discount += (row['discount'] as num?)?.toDouble() ?? 0;
      }
      for (final row in paymentRows) {
        paid += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      double opening = 0;
      if (year?['id'] != null) {
        final rows = await db.from('student_opening_balances').select('amount')
            .eq('student_id', studentId).eq('academic_year_id', year!['id'])
            .timeout(const Duration(seconds: 6));
        opening = (rows as List).fold<double>(0,
            (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
      }
      final due = totalFee - discount + opening;
      final summary = {
        'academic_year': year?['name']?.toString() ??
            (fees.isNotEmpty ? fees.first['academic_year_label']?.toString() : 'غير محدد'),
        'fees': totalFee, 'discount': discount, 'opening_balance': opening,
        'paid': paid, 'remaining': due - paid,
        'assessments': fees, 'payments': paymentRows,
      };
      if (cacheKey != null) await prefs.setString(cacheKey, jsonEncode(summary));
      return summary;
    } catch (_) {
      if (cacheKey != null) {
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {
            await prefs.remove(cacheKey);
          }
        }
      }
      final fees = await studentFeeAssessments(studentId);
      final paymentRows = await studentPayments(studentId);
      double totalFee = 0, discount = 0, paid = 0;
      for (final row in fees) {
        totalFee += (row['total_fee'] as num?)?.toDouble() ?? 0;
        discount += (row['discount'] as num?)?.toDouble() ?? 0;
      }
      for (final row in paymentRows) {
        paid += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      return {
        'academic_year': fees.isNotEmpty ? fees.first['academic_year_label']?.toString() : 'غير محدد',
        'fees': totalFee, 'discount': discount, 'opening_balance': 0,
        'paid': paid, 'remaining': totalFee - discount - paid,
        'assessments': fees, 'payments': paymentRows,
      };
    }
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
      throw Exception(
        'تحقق من الرسوم والخصم؛ يجب ألا يتجاوز الخصم قيمة الرسوم.',
      );
    }
    final p = await profile();
    final schoolId = p?.schoolId;
    if (schoolId == null ||
        (p?.role != 'admin' && p?.role != 'owner' && p?.role != 'accountant')) {
      throw Exception('ليست لديك صلاحية تعديل الرسوم الدراسية.');
    }
    if (!await _serverAvailable() || studentId.startsWith('offline-')) {
      final dedupe='$studentId:$term:${academicYearId??academicYearLabel}';
      final rows=await _cachedRows(schoolId,'fees_$studentId');
      final ix=rows.indexWhere((x)=>x['term']==term&&x['academic_year_id']?.toString()==academicYearId?.toString()&&(academicYearId!=null||x['academic_year_label']?.toString()==academicYearLabel));
      final localId=ix>=0?rows[ix]['id'].toString():_newOfflineId('fee');
      await _queueOfflineOperation(schoolId,{'type':'save_fee','local_id':localId.startsWith('offline-')?localId:null,'student_id':studentId,'term':term,'total_fee':totalFee,'discount':discount,'academic_year_id':academicYearId,'academic_year_label':academicYearLabel,'note':note.trim()},dedupeType:'save_fee',dedupeKey:dedupe);
      final row={'id':localId,'student_id':studentId,'school_id':schoolId,'academic_year_id':academicYearId,'academic_year_label':academicYearLabel,'term':term,'total_fee':totalFee,'discount':discount,'note':note.trim()};
      if(ix>=0)rows[ix]=row;else rows.add(row);await _saveRows(schoolId,'fees_$studentId',rows);
      final summaryKey=_tenantCacheKey(schoolId,'financial_summary_$studentId');final summaryRaw=prefs.getString(summaryKey);
      if(summaryRaw!=null){try{final summary=Map<String,dynamic>.from(jsonDecode(summaryRaw));summary['assessments']=rows;summary['fees']=rows.fold<double>(0,(s,x)=>s+((x['total_fee'] as num?)?.toDouble()??0));summary['discount']=rows.fold<double>(0,(s,x)=>s+((x['discount'] as num?)?.toDouble()??0));summary['remaining']=(summary['fees'] as num).toDouble()-(summary['discount'] as num).toDouble()-((summary['paid'] as num?)?.toDouble()??0);await prefs.setString(summaryKey,jsonEncode(summary));}catch(_){}}
      return;
    }
    final existingForYear = academicYearId == null
        ? await db
              .from('student_fee_assessments')
              .select('id')
              .eq('school_id', schoolId)
              .eq('student_id', studentId)
              .eq('term', term)
              .isFilter('academic_year_id', null)
              .eq('academic_year_label', academicYearLabel)
              .maybeSingle()
        : await db
              .from('student_fee_assessments')
              .select('id')
              .eq('school_id', schoolId)
              .eq('student_id', studentId)
              .eq('term', term)
              .eq('academic_year_id', academicYearId)
              .maybeSingle();
    final existingUnassigned = existingForYear == null && academicYearId != null
        ? await db
              .from('student_fee_assessments')
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
      await db
          .from('student_fee_assessments')
          .update(payload)
          .eq('id', existing!['id']);
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
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('قيمة الدفعة يجب أن تكون أكبر من صفر.');
    }
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية لتسجيل الدفعة.');
    }

    // Keep an encrypted, retry-stable idempotency key until the server confirms
    // the payment. A timeout after commit can then be retried without a second receipt.
    const secureStorage = FlutterSecureStorage();
    final pendingKey = 'lamin.pending_payments.v1_$schoolId';
    final fingerprint = jsonEncode({
      'student_id': studentId,
      'amount': amount.toStringAsFixed(2),
      'note': note.trim(),
      'term': term,
      'fee_assessment_id': feeAssessmentId,
    });
    Map<String, dynamic> pending = {};
    try {
      final raw = await secureStorage.read(key: pendingKey);
      if (raw != null) pending = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      pending = {};
    }
    var idempotencyKey = pending[fingerprint]?.toString();
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      final random = math.Random.secure();
      final randomPart = List.generate(
        4,
        (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
      ).join();
      idempotencyKey = 'lamin-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
      pending[fingerprint] = idempotencyKey;
      await secureStorage.write(key: pendingKey, value: jsonEncode(pending));
    }

    if (!await _serverAvailable() || studentId.startsWith('offline-')) {
      final localId='offline-payment-$idempotencyKey';
      await _queueOfflineOperation(schoolId,{'type':'add_payment','student_id':studentId,'amount':amount,'note':note.trim(),'term':term,'fee_assessment_id':feeAssessmentId,'idempotency_key':idempotencyKey,'fingerprint':fingerprint},dedupeType:'add_payment',dedupeKey:idempotencyKey);
      final rows=await _cachedRows(schoolId,'payments_$studentId');
      if(!rows.any((x)=>x['id']==localId)){rows.insert(0,{'id':localId,'student_id':studentId,'amount':amount,'note':note.trim(),'term':term,'fee_assessment_id':feeAssessmentId,'payment_date':DateTime.now().toIso8601String().substring(0,10),'created_at':DateTime.now().toUtc().toIso8601String(),'pending_sync':true});await _saveRows(schoolId,'payments_$studentId',rows);}
      final summaryKey=_tenantCacheKey(schoolId,'financial_summary_$studentId');final rawSummary=prefs.getString(summaryKey);
      if(rawSummary!=null){try{final summary=Map<String,dynamic>.from(jsonDecode(rawSummary));summary['payments']=rows;summary['paid']=((summary['paid'] as num?)?.toDouble()??0)+amount;summary['remaining']=((summary['remaining'] as num?)?.toDouble()??0)-amount;await prefs.setString(summaryKey,jsonEncode(summary));}catch(_){}}
      return;
    }

    final result = await db.rpc('record_student_payment', params: {
      'p_student_id': studentId,
      'p_amount': amount,
      'p_note': note.trim(),
      'p_term': term,
      'p_fee_assessment_id':
          feeAssessmentId == null || feeAssessmentId.isEmpty
              ? null
              : feeAssessmentId,
      'p_idempotency_key': idempotencyKey,
    });
    if (result == null || result.toString().isEmpty) {
      throw Exception('لم يؤكد الخادم تسجيل الدفعة.');
    }

    pending.remove(fingerprint);
    if (pending.isEmpty) {
      await secureStorage.delete(key: pendingKey);
    } else {
      await secureStorage.write(key: pendingKey, value: jsonEncode(pending));
    }
  }

  Future<Map<String, dynamic>> exportBackup() async {
    // Owner backups must pass an explicit school id to the SECURITY DEFINER RPC.
    // Admin backups remain scoped by the server-side private.my_school() check.
    final p = await profile();
    if (p?.role == 'owner') {
      final schoolId = p?.schoolId;
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception(
          'تعذر تحديد المدرسة. افتح إعداد المدرسة ثم أعد محاولة النسخ الاحتياطي.',
        );
      }
      final result = await db.rpc(
        'export_backup',
        params: {'p_school': schoolId},
      );
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'payload': result};
    }
    final result = await db.rpc('export_backup');
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'payload': result};
  }

  Future<Map<String, dynamic>> restoreBackup(
    Map<String, dynamic> backup,
  ) async {
    final result = await db.rpc('restore_backup', params: {'p_backup': backup});
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('استجابة استعادة النسخة غير صالحة.');
  }

  Future<Map<String, dynamic>?> schoolBranding() async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return null;
    final cacheKey = _tenantCacheKey(schoolId, 'school_branding');
    try {
      final row = await db
          .from('school_branding')
          .select('school_id,logo_data,logo_mime_type,updated_at')
          .eq('school_id', schoolId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (row == null) {
        await prefs.remove(cacheKey);
        return null;
      }
      final data = Map<String, dynamic>.from(row);
      await prefs.setString(cacheKey, jsonEncode(data));
      return data;
    } catch (_) {
      final raw = prefs.getString(cacheKey);
      if (raw == null) return null;
      try {
        return Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        await prefs.remove(cacheKey);
        return null;
      }
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
    final payload = {
      'school_id': schoolId,
      'logo_data': logoBase64,
      'logo_mime_type': mimeType,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await db.from('school_branding').upsert(payload);
    await prefs.setString(
      _tenantCacheKey(schoolId, 'school_branding'),
      jsonEncode(payload),
    );
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
    await prefs.remove(_tenantCacheKey(schoolId, 'school_branding'));
  }

  Future<void> deleteSchoolUser(String userId) async {
    await db.rpc('delete_school_user', params: {'p_user_id': userId});
  }

  Future<void> grantOneDriveAccess(
    String userId, {
    required String microsoftEmail,
    required String microsoftAccessToken,
    required String driveId,
    required String folderItemId,
  }) async {
    await db.functions.invoke(
      'onedrive-access',
      body: {
        'action': 'grant',
        'user_id': userId,
        'microsoft_email': microsoftEmail.trim().toLowerCase(),
        'microsoft_access_token': microsoftAccessToken,
        'drive_id': driveId,
        'folder_item_id': folderItemId,
      },
    );
  }

  Future<void> revokeOneDriveAccess(
    String userId, {
    required String microsoftAccessToken,
    required String driveId,
    required String folderItemId,
  }) async {
    await db.functions.invoke(
      'onedrive-access',
      body: {
        'action': 'revoke',
        'user_id': userId,
        'microsoft_access_token': microsoftAccessToken,
        'drive_id': driveId,
        'folder_item_id': folderItemId,
      },
    );
  }

  Future<void> disableUserAndRevokeOneDrive(
    String userId, {
    required String microsoftAccessToken,
    required String driveId,
    required String folderItemId,
  }) async {
    await db.functions.invoke(
      'onedrive-access',
      body: {
        'action': 'disable',
        'user_id': userId,
        'microsoft_access_token': microsoftAccessToken,
        'drive_id': driveId,
        'folder_item_id': folderItemId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> schoolUsers() async {
    final rows = await db
        .from('profiles')
        .select(
          'user_id,username,role,active,school_id,microsoft_email,onedrive_access_granted,onedrive_permission_id,onedrive_granted_at,onedrive_revoked_at',
        )
        .eq('school_id', (await profile())?.schoolId ?? '');
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> expenses() => _readRows(
    'expenses',
    () => db.from('expenses').select(
      'id,title,amount,category,note,created_at',
    ).order('created_at', ascending: false),
  );

  Future<void> addExpense({
    required String title,
    required double amount,
    String category = 'عام',
    String note = '',
  }) async {
    await db.from('expenses').insert({
      'title': title.trim(),
      'amount': amount,
      'category': category.trim(),
      'note': note.trim(),
    });
  }

  Future<void> queueWhatsApp({
    required String studentId,
    required String phone,
    required String kind,
    required String message,
  }) async {
    await db.from('whatsapp_notifications').insert({
      'student_id': studentId,
      'phone': phone,
      'kind': kind,
      'message': message,
    });
  }

  Future<void> signOut() => db.auth.signOut();
}