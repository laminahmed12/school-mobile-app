import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models.dart';
import 'supabase_config.dart';
import 'student_creation_rpc.dart';

bool shouldPromptOnlineLoginForPendingSync({
  required bool hasInternet,
  required bool hasAuthenticatedSession,
  required int pendingCount,
}) =>
    hasInternet && !hasAuthenticatedSession && pendingCount > 0;

class OfflineSyncResult {
  final int synced;
  final int pending;
  final String? failedOperation;
  final String? error;

  const OfflineSyncResult({
    required this.synced,
    required this.pending,
    this.failedOperation,
    this.error,
  });
}

String offlineOperationLabel(String? type) {
  switch (type) {
    case 'create_student':
      return 'إنشاء طالب';
    case 'update_student':
      return 'تعديل بيانات طالب';
    case 'save_fee':
      return 'حفظ الرسوم الدراسية';
    case 'add_payment':
      return 'تسجيل دفعة مالية';
    case 'attendance':
      return 'تسجيل الحضور';
    default:
      return 'عملية محلية غير معروفة';
  }
}

class SchoolRepository {
  final SharedPreferences prefs;
  SchoolRepository(this.prefs);

  // Offline application data is encrypted at rest through Android Keystore /
  // iOS Keychain. SharedPreferences is used only as a one-time legacy source.
  static const FlutterSecureStorage _cacheStorage = FlutterSecureStorage();

  String _secureCacheKey(String key) => 'lamin.cache.v1.$key';

  Future<String?> _readCacheString(String key) async {
    final secureKey = _secureCacheKey(key);
    try {
      final value = await _cacheStorage.read(key: secureKey);
      if (value != null) return value;
    } catch (error) {
      // Fail closed: discard an older plaintext fallback if secure storage itself
      // is unavailable, rather than exposing school data in SharedPreferences.
      try {
        await prefs.remove(key);
      } catch (_) {}
      debugPrint('Secure cache read failed for $key: $error');
      return null;
    }

    final legacy = prefs.getString(key);
    if (legacy == null) return null;
    try {
      await _cacheStorage.write(key: secureKey, value: legacy);
      await prefs.remove(key);
      return legacy;
    } catch (error) {
      // Never leave a readable plaintext copy after a failed migration.
      await prefs.remove(key);
      debugPrint('Legacy cache migration discarded for $key: $error');
      return null;
    }
  }

  Future<void> _writeCacheString(String key, String value) async {
    await _cacheStorage.write(key: _secureCacheKey(key), value: value);
    await prefs.remove(key);
  }

  Future<void> _removeCache(String key) async {
    await _cacheStorage.delete(key: _secureCacheKey(key));
    await prefs.remove(key);
  }

  Future<int?> _readCacheInt(String key) async {
    final value = await _readCacheString(key);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> _writeCacheInt(String key, int value) =>
      _writeCacheString(key, value.toString());

  Future<double?> _readCacheDouble(String key) async {
    final value = await _readCacheString(key);
    return value == null ? null : double.tryParse(value);
  }

  Future<void> _writeCacheDouble(String key, double value) =>
      _writeCacheString(key, value.toString());

  Future<String?> _userId() async {
    final currentUserId = db.auth.currentUser?.id;
    if (currentUserId != null && currentUserId.isNotEmpty) return currentUserId;
    return const FlutterSecureStorage().read(key: 'lamin.offline.user.id');
  }

  String _profileCacheKey(String userId) => 'lamin_profile_cache_v1_$userId';
  String _schoolCacheKey(String schoolId) => 'lamin_school_cache_v1_$schoolId';
  String _tenantCacheKey(String schoolId, String table) => 'lamin_data_cache_v1_${schoolId}_$table';

  Future<List<Map<String, dynamic>>> _cachedRows(String schoolId, String key) async {
    final raw = await _readCacheString(_tenantCacheKey(schoolId, key));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      await _removeCache(_tenantCacheKey(schoolId, key));
      return [];
    }
  }

  Future<void> _saveRows(String schoolId, String key, List rows) async {
    await _writeCacheString(_tenantCacheKey(schoolId, key), jsonEncode(rows));
  }

  Future<String?> _schoolId() async {
    final userId = await _userId();
    if (userId == null) return null;
    return await _readCacheString('school_id_cache_$userId') ??
        (await cachedProfile())?.schoolId;
  }

  Future<List<Map<String, dynamic>>> _readRows(
    String key,
    Future<dynamic> Function() request, {
    bool cacheOnly = false,
  }) async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return [];
    if (cacheOnly || !await _serverAvailable()) {
      return _cachedRows(schoolId, key);
    }
    try {
      final result = await request().timeout(const Duration(seconds: 4));
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
    const secureStorage = FlutterSecureStorage();
    final raw = await secureStorage.read(key: _offlineQueueKey(schoolId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
    } catch (_) {
      throw Exception('تعذر قراءة قائمة التعديلات المحلية المحفوظة بأمان.');
    }
  }

  Future<void> _writeOfflineOperations(
    String schoolId,
    List<Map<String, dynamic>> rows,
  ) async {
    const secureStorage = FlutterSecureStorage();
    final key = _offlineQueueKey(schoolId);
    if (rows.isEmpty) {
      await secureStorage.delete(key: key);
    } else {
      await secureStorage.write(key: key, value: jsonEncode(rows));
    }
  }

  Future<void> _queueOfflineOperation(
    String schoolId,
    Map<String, dynamic> op, {
    String? dedupeType,
    String? dedupeKey,
    String? operationId,
  }) async {
    final rows = await _readOfflineOperations(schoolId);
    if (dedupeType != null && dedupeKey != null) {
      rows.removeWhere(
        (row) => row['type'] == dedupeType && row['dedupe_key'] == dedupeKey,
      );
    }
    rows.add({
      'operation_id': operationId ?? _newOfflineId('op'),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      ...op,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
    });
    await _writeOfflineOperations(schoolId, rows);
  }

  bool _isNetworkFailure(Object error) {
    if (error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('timed out') ||
        message.contains('no address associated with hostname');
  }

  DateTime? _serverProbeAt;
  bool? _serverProbeResult;
  Future<bool>? _serverProbeInFlight;

  Future<bool> _serverAvailable() async {
    final user = db.auth.currentUser;
    // After a cold-start offline login there is no Supabase access token yet.
    // Do not make a profiles probe: local queue writes can proceed immediately.
    if (user == null || db.auth.currentSession == null) return false;

    final now = DateTime.now();
    if (_serverProbeAt != null &&
        _serverProbeResult != null &&
        now.difference(_serverProbeAt!) < const Duration(seconds: 2)) {
      return _serverProbeResult!;
    }
    final inFlight = _serverProbeInFlight;
    if (inFlight != null) return inFlight;

    final probe = () async {
      try {
        final connections = await Connectivity().checkConnectivity().timeout(
          const Duration(milliseconds: 400),
        );
        if (connections.contains(ConnectivityResult.none)) return false;
      } catch (_) {
        return false;
      }

      try {
        final row = await db
            .from('profiles')
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 1));
        return row != null;
      } catch (_) {
        return false;
      }
    }();

    _serverProbeInFlight = probe;
    try {
      final available = await probe;
      _serverProbeAt = DateTime.now();
      _serverProbeResult = available;
      return available;
    } finally {
      _serverProbeInFlight = null;
    }
  }

  Future<List<Map<String,dynamic>>> _cachedStudentMaps(String schoolId) async {
    final raw=await _readCacheString('students_cache_$schoolId');
    if(raw==null)return [];
    try{return (jsonDecode(raw) as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();}
    catch(_){return [];}
  }
  Future<void> _cacheStudent(String schoolId,{required String id,required String name,required String className,required String phone}) async {
    final rows=await _cachedStudentMaps(schoolId);
    final index=rows.indexWhere((x)=>x['id']?.toString()==id);
    final value={'id':id,'name':name.trim(),'class_name':className.trim(),'phone':phone.trim()};
    if(index<0)rows.insert(0,value);else rows[index]={...rows[index],...value};
    await _writeCacheString('students_cache_$schoolId',jsonEncode(rows));
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
  Future<int> pendingOfflineOperationCount() async {
    final cached = await cachedProfile();
    final schoolId = cached?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return 0;
    return (await _readOfflineOperations(schoolId)).length;
  }

  Future<OfflineSyncResult> syncPendingOfflineChanges() async {
    if (db.auth.currentSession == null) {
      return OfflineSyncResult(
        synced: 0,
        pending: await pendingOfflineOperationCount(),
      );
    }

    final p = await profile();
    final schoolId = p?.schoolId;
    if (schoolId == null || schoolId.isEmpty || !await _serverAvailable()) {
      return OfflineSyncResult(
        synced: 0,
        pending: await pendingOfflineOperationCount(),
      );
    }

    final queue = await _readOfflineOperations(schoolId);
    if (queue.isEmpty) {
      return const OfflineSyncResult(synced: 0, pending: 0);
    }

    final mapKey = 'lamin_offline_id_map_v1_$schoolId';
    Map<String, dynamic> idMap = {};
    try {
      final raw = await _readCacheString(mapKey);
      if (raw != null) idMap = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {}

    String resolve(dynamic value) {
      final id = value?.toString() ?? '';
      return idMap[id]?.toString() ?? id;
    }

    var synced = 0;
    while (queue.isNotEmpty) {
      final item = queue.first;
      final type = item['type']?.toString();
      try {
        if (type == 'create_student') {
          final result = await db.rpc(
            studentCreateIdempotentRpc,
            params: buildStudentCreationRpcParams(
              operationId: item['operation_id']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              className: item['class_name']?.toString() ?? '',
              phone: item['phone']?.toString() ?? '',
              termFee: (item['term_fee'] as num?) ?? 0,
              term: item['term']?.toString() ?? 'الفصل الأول',
            ),
          ).timeout(const Duration(seconds: 6));
          final remote = result?.toString() ?? '';
          if (remote.isEmpty) {
            throw Exception('لم يؤكد الخادم إنشاء الطالب.');
          }

          final local = item['local_id'].toString();
          idMap[local] = remote;
          await _writeCacheString(mapKey, jsonEncode(idMap));
          final students = await _cachedStudentMaps(schoolId);
          final index = students.indexWhere(
            (row) => row['id']?.toString() == local,
          );
          if (index >= 0) {
            students[index]['id'] = remote;
            await _writeCacheString(
              'students_cache_$schoolId',
              jsonEncode(students),
            );
          }
        } else if (type == 'update_student') {
          await db
              .from('students')
              .update({
                'name': item['name'],
                'class_name': item['class_name'],
                'phone': item['phone'] ?? '',
              })
              .eq('id', resolve(item['student_id']))
              .timeout(const Duration(seconds: 6));
        } else if (type == 'save_fee') {
          final studentId = resolve(item['student_id']);
          final yearId = item['academic_year_id'];
          final payload = {
            'school_id': schoolId,
            'student_id': studentId,
            'academic_year_id': yearId,
            'academic_year_label':
                item['academic_year_label'] ?? 'غير محدد',
            'term': item['term'],
            'total_fee': item['total_fee'],
            'discount': item['discount'] ?? 0,
            'note': item['note'] ?? '',
            'created_by': db.auth.currentUser?.id,
          };
          final base = db
              .from('student_fee_assessments')
              .select('id')
              .eq('school_id', schoolId)
              .eq('student_id', studentId)
              .eq('term', item['term']);
          final existing = yearId == null
              ? await base
                  .isFilter('academic_year_id', null)
                  .eq(
                    'academic_year_label',
                    item['academic_year_label'] ?? 'غير محدد',
                  )
                  .maybeSingle()
                  .timeout(const Duration(seconds: 6))
              : await base
                  .eq('academic_year_id', yearId)
                  .maybeSingle()
                  .timeout(const Duration(seconds: 6));
          final existingId = existing == null ? null : existing['id'];
          final saved = existingId != null
              ? await db
                    .from('student_fee_assessments')
                    .update(payload)
                    .eq('id', existingId)
                    .select('id')
                    .single()
                    .timeout(const Duration(seconds: 6))
              : await db
                    .from('student_fee_assessments')
                    .insert(payload)
                    .select('id')
                    .single()
                    .timeout(const Duration(seconds: 6));

          final localFee = item['local_id']?.toString();
          final remoteFee = saved['id']?.toString();
          if (localFee != null && remoteFee != null) {
            idMap[localFee] = remoteFee;
            await _writeCacheString(mapKey, jsonEncode(idMap));
          }

          final rows = await _cachedRows(schoolId, 'fees_$studentId');
          final index = rows.indexWhere(
            (row) =>
                row['term'] == item['term'] &&
                row['academic_year_id']?.toString() == yearId?.toString(),
          );
          final cached = {
            ...payload,
            'id': remoteFee ?? localFee ?? '',
          };
          if (index >= 0) {
            rows[index] = cached;
          } else {
            rows.add(cached);
          }
          await _saveRows(schoolId, 'fees_$studentId', rows);
        } else if (type == 'add_payment') {
          final result = await db.rpc(
            'record_student_payment',
            params: {
              'p_student_id': resolve(item['student_id']),
              'p_amount': item['amount'],
              'p_note': item['note'] ?? '',
              'p_term': item['term'] ?? 'غير محدد',
              'p_fee_assessment_id': item['fee_assessment_id'] == null
                  ? null
                  : resolve(item['fee_assessment_id']),
              'p_idempotency_key': item['idempotency_key'],
            },
          ).timeout(const Duration(seconds: 6));
          if (result == null || result.toString().isEmpty) {
            throw Exception('لم يؤكد الخادم تسجيل الدفعة.');
          }

          const secure = FlutterSecureStorage();
          final pendingKey = 'lamin.pending_payments.v1_$schoolId';
          try {
            final raw = await secure.read(key: pendingKey);
            if (raw != null) {
              final pending = Map<String, dynamic>.from(jsonDecode(raw));
              pending.remove(item['fingerprint']);
              if (pending.isEmpty) {
                await secure.delete(key: pendingKey);
              } else {
                await secure.write(
                  key: pendingKey,
                  value: jsonEncode(pending),
                );
              }
            }
          } catch (_) {}
        } else if (type == 'attendance') {
          await _writeAttendanceRemote(
            studentId: resolve(item['student_id']),
            date: item['attendance_date'].toString(),
            status: item['status'].toString(),
            minutesLate: (item['minutes_late'] as num?)?.toInt() ?? 0,
          ).timeout(const Duration(seconds: 6));
        } else {
          throw Exception('نوع عملية محلية غير معروف: $type');
        }

        queue.removeAt(0);
        await _writeOfflineOperations(schoolId, queue);
        synced++;
      } catch (error) {
        debugPrint('Offline sync paused at $type: $error');
        return OfflineSyncResult(
          synced: synced,
          pending: queue.length,
          failedOperation: type,
          error: isMissingStudentCreationRpc(error)
              ? studentCreationRpcUnavailableMessage
              : error.toString(),
        );
      }
    }

    return OfflineSyncResult(synced: synced, pending: queue.length);
  }

  Future<SchoolProfile?> cachedProfileForUser(String userId) async {
    if (userId.isEmpty) return null;
    final raw = await _readCacheString(_profileCacheKey(userId));
    if (raw == null) return null;
    try {
      return SchoolProfile.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<SchoolProfile?> cachedProfile() async {
    final userId = await _userId();
    if (userId == null) return null;
    return cachedProfileForUser(userId);
  }

  Future<Map<String, dynamic>?> cachedSchoolForId(String schoolId) async {
    if (schoolId.isEmpty) return null;
    final raw = await _readCacheString(_schoolCacheKey(schoolId));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> cachedSchool() async {
    final p = await cachedProfile();
    final schoolId = p?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return null;
    return cachedSchoolForId(schoolId);
  }

  Future<SchoolProfile?> profile() async {
    final user = db.auth.currentUser;
    if (user == null) return cachedProfile();

    final cached = await cachedProfileForUser(user.id);
    if (!await _serverAvailable()) return cached;
    try {
      final row = await db
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      if (row == null) return cached;

      final profile = SchoolProfile.fromMap(row);
      await _writeCacheString(
        _profileCacheKey(user.id),
        jsonEncode(Map<String, dynamic>.from(row)),
      );
      await const FlutterSecureStorage().write(
        key: 'lamin.offline.user.id',
        value: user.id,
      );
      final schoolId = profile.schoolId;
      if (schoolId != null && schoolId.isNotEmpty) {
        await _writeCacheString('school_id_cache_${user.id}', schoolId);
      }
      return profile;
    } catch (_) {
      return cached;
    }
  }

  Future<Map<String, dynamic>?> school() async {
    final cachedProfile = await this.cachedProfile();
    final p = cachedProfile ?? await profile();
    final id = p?.schoolId;
    if (id == null || id.isEmpty) return null;

    final cached = await cachedSchoolForId(id);
    if (!await _serverAvailable()) return cached;
    try {
      final row = await db
          .from('schools')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      if (row == null) return cached;
      final data = Map<String, dynamic>.from(row);
      await _writeCacheString(_schoolCacheKey(id), jsonEncode(data));
      return data;
    } catch (_) {
      return cached;
    }
  }



  Future<String?> ensureOwnerSchool({
    String code = 'lamin',
    String name = 'مدرسة لامين التجريبية',
  }) async {
    try {
      var p = await cachedProfile().timeout(
        const Duration(seconds: 2),
      );
      if (p?.schoolId == null) {
        p = await profile().timeout(
          const Duration(seconds: 4),
          onTimeout: () => cachedProfile(),
        );
      }
      if (p?.schoolId != null) return p!.schoolId;
      if (!await _serverAvailable()) return null;
      final result = await db
          .rpc(
            'bootstrap_owner_school',
            params: {'p_code': code, 'p_name': name},
          )
          .timeout(const Duration(seconds: 4));
      return result?.toString();
    } catch (_) {
      return null;
    }
  }



  Future<List<Student>> students({bool cacheOnly = false}) async {
    final userId = await _userId();
    if (userId == null || userId.isEmpty) return [];

    final schoolId =
        await _readCacheString('school_id_cache_$userId') ??
        (await cachedProfileForUser(userId))?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return [];

    final cacheKey = 'students_cache_$schoolId';

    Future<List<Student>> fromCache() async {
      final raw = await _readCacheString(cacheKey);
      if (raw == null) return [];
      try {
        final merged = (jsonDecode(raw) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        final pending = await _readOfflineOperations(schoolId);
        for (final operation in pending) {
          if (operation['type'] == 'create_student') {
            merged.removeWhere(
              (row) => row['id']?.toString() == operation['local_id']?.toString(),
            );
            merged.add({
              'id': operation['local_id'],
              'name': operation['name'],
              'class_name': operation['class_name'],
              'phone': operation['phone'] ?? '',
            });
          } else if (operation['type'] == 'update_student') {
            final index = merged.indexWhere(
              (row) =>
                  row['id']?.toString() ==
                  operation['student_id']?.toString(),
            );
            if (index >= 0) {
              merged[index] = {
                ...merged[index],
                'name': operation['name'],
                'class_name': operation['class_name'],
                'phone': operation['phone'] ?? '',
              };
            }
          }
        }
        merged.sort(
          (a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()),
        );
        return merged.map(Student.fromMap).toList();
      } catch (_) {
        return [];
      }
    }

    if (cacheOnly || !await _serverAvailable()) return fromCache();

    try {
      final rows = await db
          .from('students')
          .select()
          .isFilter('archived_at', null)
          .order('name')
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((row) => Student.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      final merged = list
          .map(
            (student) => {
              'id': student.id,
              'name': student.name,
              'class_name': student.className,
              'phone': student.phone,
            },
          )
          .toList();

      final pending = await _readOfflineOperations(schoolId);
      for (final operation in pending) {
        if (operation['type'] == 'create_student') {
          merged.removeWhere(
            (row) => row['id']?.toString() == operation['local_id']?.toString(),
          );
          merged.add({
            'id': operation['local_id'],
            'name': operation['name'],
            'class_name': operation['class_name'],
            'phone': operation['phone'] ?? '',
          });
        } else if (operation['type'] == 'update_student') {
          final index = merged.indexWhere(
            (row) =>
                row['id']?.toString() ==
                operation['student_id']?.toString(),
          );
          if (index >= 0) {
            merged[index] = {
              ...merged[index],
              'name': operation['name'],
              'class_name': operation['class_name'],
              'phone': operation['phone'] ?? '',
            };
          }
        }
      }
      merged.sort(
        (a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()),
      );
      await _writeCacheString(cacheKey, jsonEncode(merged));
      return merged.map(Student.fromMap).toList();
    } catch (_) {
      return fromCache();
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
        await _removeCache(key);
        return null;
      }
      final data = Map<String, dynamic>.from(row);
      await _writeCacheString(key, jsonEncode(data));
      return data;
    } catch (_) {
      final raw = await _readCacheString(key);
      if (raw == null) return null;
      try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {
        await _removeCache(key);
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
    }).timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> dailySummary(DateTime day) async {
    final d = day.toIso8601String().substring(0, 10);
    final schoolId = await _schoolId();
    final cacheKey = schoolId == null ? null : _tenantCacheKey(schoolId, 'daily_summary_$d');
    Map<String, dynamic> result = {};
    try {
      final r = await db.rpc('school_daily_summary', params: {'p_date': d})
          .timeout(const Duration(seconds: 5));
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
            .timeout(const Duration(seconds: 5)) as List;
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
      if (cacheKey != null) await _writeCacheString(cacheKey, jsonEncode(result));
      return result;
    } catch (_) {
      if (cacheKey == null) return result;
      final raw = await _readCacheString(cacheKey);
      if (raw == null) return result;
      try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {
        await _removeCache(cacheKey);
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
    }).timeout(const Duration(seconds: 5));
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
        await _writeCacheString(cacheKey, name);
      }
      return name;
    } catch (_) {
      return cacheKey == null ? null : await _readCacheString(cacheKey);
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
    ).timeout(const Duration(seconds: 6));
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
    ).timeout(const Duration(seconds: 5));
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
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      yearId = active?['id']?.toString();
    }
    await db.from('classes').insert({
      'name': name.trim(),
      'section': section.trim(),
      if (yearId != null && yearId.isNotEmpty) 'academic_year_id': yearId,
    }).timeout(const Duration(seconds: 5));
  }

  Future<void> addSubject(String name) async {
    await db.from('subjects')
        .insert({'name': name.trim()})
        .timeout(const Duration(seconds: 5));
  }

  Future<List<Teacher>> teachers({bool cacheOnly = false}) async {
    final userId = await _userId();
    if (userId == null || userId.isEmpty) return [];
    final schoolId =
        await _readCacheString('school_id_cache_$userId') ??
        (await cachedProfileForUser(userId))?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return [];

    Future<List<Teacher>> fromCache() async =>
        (await _cachedRows(schoolId, 'teachers'))
            .map(Teacher.fromMap)
            .toList();

    if (cacheOnly || !await _serverAvailable()) return fromCache();
    try {
      final rows = await db
          .from('teachers')
          .select()
          .isFilter('archived_at', null)
          .order('name')
          .timeout(const Duration(seconds: 4));
      final raw = (rows as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      await _saveRows(schoolId, 'teachers', raw);
      return raw.map(Teacher.fromMap).toList();
    } catch (_) {
      return fromCache();
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

  Future<void> _writeAttendanceRemote({
    required String studentId,
    required String date,
    required String status,
    required int minutesLate,
  }) async {
    final matches = await db.from('attendance').select('id')
        .eq('student_id', studentId).eq('attendance_date', date).limit(1);
    final payload = {
      'student_id': studentId,
      'attendance_date': date,
      'status': status,
      'minutes_late': minutesLate,
    };
    if ((matches as List).isNotEmpty) {
      await db.from('attendance').update({
        'status': status,
        'minutes_late': minutesLate,
      }).eq('student_id', studentId).eq('attendance_date', date);
    } else {
      await db.from('attendance').insert(payload);
    }
  }

  Future<void> saveAttendance({
    required String studentId,
    required DateTime day,
    required String status,
    int minutesLate = 0,
  }) async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية.');
    }
    final date = day.toIso8601String().substring(0, 10);

    Future<void> queueLocally() async {
      await _queueOfflineOperation(
        schoolId,
        {
          'type': 'attendance',
          'student_id': studentId,
          'attendance_date': date,
          'status': status,
          'minutes_late': minutesLate,
        },
        dedupeType: 'attendance',
        dedupeKey: '$studentId:$date',
      );
      final rows = await _cachedRows(schoolId, 'attendance_$date');
      rows.removeWhere((row) => row['student_id']?.toString() == studentId);
      rows.add({
        'id': _newOfflineId('attendance'),
        'student_id': studentId,
        'school_id': schoolId,
        'attendance_date': date,
        'status': status,
        'minutes_late': minutesLate,
      });
      await _saveRows(schoolId, 'attendance_$date', rows);
    }

    if (studentId.startsWith('offline-') || !await _serverAvailable()) {
      await queueLocally();
      return;
    }
    try {
      await _writeAttendanceRemote(
        studentId: studentId,
        date: date,
        status: status,
        minutesLate: minutesLate,
      ).timeout(const Duration(seconds: 5));
    } catch (error) {
      if (!_isNetworkFailure(error)) rethrow;
      await queueLocally();
    }
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
    }).timeout(const Duration(seconds: 5));
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
      await _writeCacheInt(cacheKey, value);
      return value;
    } catch (_) {
      return await _readCacheInt(cacheKey) ?? 0;
    }
  }

  Future<double> paymentsTotal({bool cacheOnly = false}) async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return 0;
    final cacheKey = 'lamin_payments_total_$schoolId';
    final cached = await _readCacheDouble(cacheKey) ?? 0;
    if (cacheOnly || !await _serverAvailable()) return cached;
    try {
      final total = await _sumColumnPaged('payments', 'amount')
          .timeout(const Duration(seconds: 5));
      await _writeCacheDouble(cacheKey, total);
      return total;
    } catch (_) {
      return cached;
    }
  }

  Future<double> expensesTotal({bool cacheOnly = false}) async {
    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) return 0;
    final cacheKey = 'lamin_expenses_total_$schoolId';
    final cached = await _readCacheDouble(cacheKey) ?? 0;
    if (cacheOnly || !await _serverAvailable()) return cached;
    try {
      final totals = await Future.wait<double>([
        _sumColumnPaged('expenses', 'amount')
            .timeout(const Duration(seconds: 5)),
        _sumColumnPaged('payroll_transactions', 'amount')
            .timeout(const Duration(seconds: 5)),
      ]);
      final total = totals[0] + totals[1];
      await _writeCacheDouble(cacheKey, total);
      return total;
    } catch (_) {
      return cached;
    }
  }



  Future<List<Map<String, dynamic>>> archivedPeople({String query = ''}) async {
    if (db.auth.currentSession == null) {
      throw Exception('يلزم الاتصال بالإنترنت لعرض الأرشيف.');
    }
    final normalizedQuery = query.trim();
    try {
      final result = await db.rpc('list_archive', params: {
        'p_query': normalizedQuery,
      }).timeout(const Duration(seconds: 12));
      return (result as List)
          .map((row) {
            final record = Map<String, dynamic>.from(row as Map);
            record['details'] ??= record['detail'] ?? '';
            return record;
          })
          .toList();
    } on PostgrestException catch (error) {
      // Older deployed databases expose list_archive(p_kind), not
      // list_archive(p_query). Support that signature without requiring
      // a production migration during app startup.
      if (error.code != 'PGRST202') rethrow;
      final results = await Future.wait([
        for (final kind in ['student', 'teacher', 'staff'])
          db.rpc('list_archive', params: {'p_kind': kind})
              .timeout(const Duration(seconds: 12)),
      ]);
      final rows = results
          .expand((result) => result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((row) {
            if (normalizedQuery.isEmpty) return true;
            final name = row['name']?.toString() ?? '';
            return name.toLowerCase().contains(normalizedQuery.toLowerCase());
          })
          .toList();
      rows.sort((a, b) {
        final left = DateTime.tryParse(a['archived_at']?.toString() ?? '');
        final right = DateTime.tryParse(b['archived_at']?.toString() ?? '');
        return (right ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(left ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
      return rows;
    }
  }

  Future<void> restorePerson({required String kind, required String id}) async {
    if (db.auth.currentSession == null) throw Exception('يلزم الاتصال بالإنترنت لاستعادة السجل.');
    await db.rpc('restore_person', params: {'p_kind': kind, 'p_id': id})
        .timeout(const Duration(seconds: 12));
  }

  Future<void> archivePerson({required String kind, required String id}) async {
    await db.rpc('archive_person', params: {
      'p_kind': kind,
      'p_id': id,
      'p_reason': 'other',
      'p_note': '',
    }).timeout(const Duration(seconds: 8));
  }

  Future<List<Map<String, dynamic>>> staffMembers() => _readRows(
    'staff',
    () => db.from('staff').select('id,name,role,phone,salary,active,created_at,archived_at').isFilter('archived_at', null).order('name'),
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
    }).timeout(const Duration(seconds: 5));
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
        })
        .eq('id', teacherId)
        .timeout(const Duration(seconds: 5));
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
        .eq('id', staffId)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> setTeacherSalary(String teacherId, double salary) async {
    await db.from('teachers').update({'salary': salary}).eq('id', teacherId)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> setStaffSalary(String staffId, double salary) async {
    await db.from('staff').update({'salary': salary}).eq('id', staffId)
        .timeout(const Duration(seconds: 5));
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
    }).timeout(const Duration(seconds: 5));
  }

  Future<String> addStudent({
    required String name,
    required String className,
    required String phone,
    double termFee = 0,
    String term = 'الفصل الأول',
  }) async {
    if (name.trim().length < 2 ||
        className.trim().isEmpty ||
        termFee < 0) {
      throw Exception('تحقق من اسم الطالب والصف والرسوم.');
    }

    final schoolId = await _schoolId();
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية.');
    }

    // Reuse the same idempotency receipt if a request times out after the
    // server has committed. This keeps the UI responsive without duplicate
    // student records when synchronization retries the queued operation.
    final operationId = _newOfflineId('student-operation');

    Future<String> queueLocally() async {
      final localId = _newOfflineId('student');
      await _queueOfflineOperation(
        schoolId,
        {
          'type': 'create_student',
          'local_id': localId,
          'name': name.trim(),
          'class_name': className.trim(),
          'phone': phone.trim(),
          'term_fee': termFee,
          'term': term,
        },
        operationId: operationId,
      );
      await _cacheStudent(
        schoolId,
        id: localId,
        name: name,
        className: className,
        phone: phone,
      );
      return localId;
    }

    if (!await _serverAvailable()) return queueLocally();

    try {
      final result = await db.rpc(
        studentCreateIdempotentRpc,
        params: buildStudentCreationRpcParams(
          operationId: operationId,
          name: name,
          className: className,
          phone: phone,
          termFee: termFee,
          term: term,
        ),
      ).timeout(const Duration(seconds: 5));

      final id = result?.toString() ?? '';
      if (id.isEmpty) {
        throw Exception('لم يُرجع الخادم رقم الطالب الجديد.');
      }
      await _cacheStudent(
        schoolId,
        id: id,
        name: name,
        className: className,
        phone: phone,
      );
      return id;
    } catch (error) {
      if (_isNetworkFailure(error) || isMissingStudentCreationRpc(error)) {
        return queueLocally();
      }
      rethrow;
    }
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
    }).timeout(const Duration(seconds: 5));
  }

  Future<List<Map<String, dynamic>>> studentFeeAssessments(
    String studentId,
  ) async {
    final schoolId = await _schoolId();
    if (schoolId == null) return [];
    if (db.auth.currentSession == null) {
      return _cachedRows(schoolId, 'fees_$studentId');
    }
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
    if (db.auth.currentSession == null) {
      return _cachedRows(schoolId, 'payments_$studentId');
    }
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

    // Local offline authentication is not a Supabase session. Never issue
    // finance queries with the anonymous role or present missing remote data
    // as a genuine zero balance.
    if (db.auth.currentSession == null) {
      if (cacheKey != null) {
        final raw = await _readCacheString(cacheKey);
        if (raw != null) {
          try {
            return {
              ...Map<String, dynamic>.from(jsonDecode(raw)),
              'requires_online_session': true,
              'has_cached_financial_data': true,
            };
          } catch (_) {
            await _removeCache(cacheKey);
          }
        }
      }

      final fees = schoolId == null
          ? <Map<String, dynamic>>[]
          : await _cachedRows(schoolId, 'fees_$studentId');
      final paymentRows = schoolId == null
          ? <Map<String, dynamic>>[]
          : await _cachedRows(schoolId, 'payments_$studentId');
      double totalFee = 0, discount = 0, paid = 0;
      for (final row in fees) {
        totalFee += (row['total_fee'] as num?)?.toDouble() ?? 0;
        discount += (row['discount'] as num?)?.toDouble() ?? 0;
      }
      for (final row in paymentRows) {
        paid += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      return {
        'academic_year': fees.isNotEmpty
            ? fees.first['academic_year_label']?.toString()
            : 'غير محدد',
        'fees': totalFee,
        'discount': discount,
        'opening_balance': 0,
        'paid': paid,
        'remaining': totalFee - discount - paid,
        'assessments': fees,
        'payments': paymentRows,
        'requires_online_session': true,
        'has_cached_financial_data': fees.isNotEmpty || paymentRows.isNotEmpty,
      };
    }

    try {
      final details = await Future.wait<Object?>([
        studentFeeAssessments(studentId),
        studentPayments(studentId),
        db.from('academic_years').select('id,name')
            .eq('active', true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 6)),
      ]);
      final fees = details[0] as List<Map<String, dynamic>>;
      final paymentRows = details[1] as List<Map<String, dynamic>>;
      final year = details[2] as Map<String, dynamic>?;
      double totalFee = 0, discount = 0, paid = 0;
      for (final row in fees) {
        totalFee += (row['total_fee'] as num?)?.toDouble() ?? 0;
        discount += (row['discount'] as num?)?.toDouble() ?? 0;
      }
      for (final row in paymentRows) {
        paid += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      double opening = 0;
      if (year != null && year['id'] != null) {
        final rows = await db.from('student_opening_balances').select('amount')
            .eq('student_id', studentId).eq('academic_year_id', year['id'])
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
        'requires_online_session': false,
        'has_cached_financial_data': true,
      };
      if (cacheKey != null) await _writeCacheString(cacheKey, jsonEncode(summary));
      return summary;
    } catch (_) {
      if (cacheKey != null) {
        final raw = await _readCacheString(cacheKey);
        if (raw != null) {
          try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {
            await _removeCache(cacheKey);
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

  Future<void> _queueStudentFeeAssessment({
    required String schoolId,
    required String studentId,
    required String term,
    required double totalFee,
    required double discount,
    required String? academicYearId,
    required String academicYearLabel,
    required String note,
  }) async {
    final dedupe =
        '$studentId:$term:${academicYearId ?? academicYearLabel}';
    final rows = await _cachedRows(schoolId, 'fees_$studentId');
    final index = rows.indexWhere(
      (row) =>
          row['term'] == term &&
          row['academic_year_id']?.toString() ==
              academicYearId?.toString() &&
          (academicYearId != null ||
              row['academic_year_label']?.toString() == academicYearLabel),
    );
    final localId = index >= 0
        ? rows[index]['id'].toString()
        : _newOfflineId('fee');

    await _queueOfflineOperation(
      schoolId,
      {
        'type': 'save_fee',
        'local_id': localId.startsWith('offline-') ? localId : null,
        'student_id': studentId,
        'term': term,
        'total_fee': totalFee,
        'discount': discount,
        'academic_year_id': academicYearId,
        'academic_year_label': academicYearLabel,
        'note': note.trim(),
      },
      dedupeType: 'save_fee',
      dedupeKey: dedupe,
    );

    final row = {
      'id': localId,
      'student_id': studentId,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'academic_year_label': academicYearLabel,
      'term': term,
      'total_fee': totalFee,
      'discount': discount,
      'note': note.trim(),
    };
    if (index >= 0) {
      rows[index] = row;
    } else {
      rows.add(row);
    }
    await _saveRows(schoolId, 'fees_$studentId', rows);

    final summaryKey =
        _tenantCacheKey(schoolId, 'financial_summary_$studentId');
    final summaryRaw = await _readCacheString(summaryKey);
    if (summaryRaw == null) return;
    try {
      final summary = Map<String, dynamic>.from(jsonDecode(summaryRaw));
      summary['assessments'] = rows;
      summary['fees'] = rows.fold<double>(
        0,
        (sum, item) =>
            sum + ((item['total_fee'] as num?)?.toDouble() ?? 0),
      );
      summary['discount'] = rows.fold<double>(
        0,
        (sum, item) =>
            sum + ((item['discount'] as num?)?.toDouble() ?? 0),
      );
      summary['remaining'] =
          (summary['fees'] as num).toDouble() -
          (summary['discount'] as num).toDouble() -
          ((summary['paid'] as num?)?.toDouble() ?? 0);
      await _writeCacheString(summaryKey, jsonEncode(summary));
    } catch (_) {}
  }

  Future<void> _queueOfflinePayment({
    required String schoolId,
    required String studentId,
    required double amount,
    required String note,
    required String term,
    required String? feeAssessmentId,
    required String idempotencyKey,
    required String fingerprint,
  }) async {
    final localId = 'offline-payment-$idempotencyKey';
    await _queueOfflineOperation(
      schoolId,
      {
        'type': 'add_payment',
        'student_id': studentId,
        'amount': amount,
        'note': note,
        'term': term,
        'fee_assessment_id': feeAssessmentId,
        'idempotency_key': idempotencyKey,
        'fingerprint': fingerprint,
      },
      dedupeType: 'add_payment',
      dedupeKey: idempotencyKey,
    );

    final rows = await _cachedRows(schoolId, 'payments_$studentId');
    if (rows.any((row) => row['id'] == localId)) return;
    rows.insert(0, {
      'id': localId,
      'student_id': studentId,
      'school_id': schoolId,
      'amount': amount,
      'note': note,
      'term': term,
      'fee_assessment_id': feeAssessmentId,
      'payment_date': DateTime.now().toIso8601String().substring(0, 10),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'pending_sync': true,
    });
    await _saveRows(schoolId, 'payments_$studentId', rows);

    final summaryKey =
        _tenantCacheKey(schoolId, 'financial_summary_$studentId');
    final rawSummary = await _readCacheString(summaryKey);
    if (rawSummary == null) return;
    try {
      final summary = Map<String, dynamic>.from(jsonDecode(rawSummary));
      summary['payments'] = rows;
      summary['paid'] =
          ((summary['paid'] as num?)?.toDouble() ?? 0) + amount;
      summary['remaining'] =
          ((summary['remaining'] as num?)?.toDouble() ?? 0) - amount;
      await _writeCacheString(summaryKey, jsonEncode(summary));
    } catch (_) {}
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
    final SchoolProfile currentProfile = await _requireCurrentProfile();
    final String? profileSchoolId = currentProfile.schoolId;
    if (profileSchoolId == null ||
        profileSchoolId.isEmpty ||
        (currentProfile.role != 'admin' &&
            currentProfile.role != 'owner' &&
            currentProfile.role != 'accountant')) {
      throw Exception('ليست لديك صلاحية تعديل الرسوم الدراسية.');
    }
    final String authorizedSchoolId = profileSchoolId;

    if (studentId.startsWith('offline-') || !await _serverAvailable()) {
      await _queueStudentFeeAssessment(
        schoolId: authorizedSchoolId,
        studentId: studentId,
        term: term,
        totalFee: totalFee,
        discount: discount,
        academicYearId: academicYearId,
        academicYearLabel: academicYearLabel,
        note: note,
      );
      return;
    }

    return _saveFeeAssessmentOnline(
      schoolId: authorizedSchoolId,
      studentId: studentId,
      term: term,
      totalFee: totalFee,
      discount: discount,
      academicYearId: academicYearId,
      academicYearLabel: academicYearLabel,
      note: note,
    );
  }

  Future<SchoolProfile> _requireCurrentProfile() async {
    final cachedProfileValue = await cachedProfile();
    if (cachedProfileValue != null) return cachedProfileValue;
    await profile();
    final refreshedProfileValue = await cachedProfile();
    if (refreshedProfileValue == null) {
      throw Exception('تعذر تحديد حساب المدرسة الحالي.');
    }
    return refreshedProfileValue;
  }

  Future<void> _saveFeeAssessmentOnline({
    required String schoolId,
    required String studentId,
    required String term,
    required double totalFee,
    required double discount,
    String? academicYearId,
    required String academicYearLabel,
    required String note,
  }) async {
    try {
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
              .timeout(const Duration(seconds: 5))
          : await db
              .from('student_fee_assessments')
              .select('id')
              .eq('school_id', schoolId)
              .eq('student_id', studentId)
              .eq('term', term)
              .eq('academic_year_id', academicYearId)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));

      final existingUnassigned =
          existingForYear == null && academicYearId != null
          ? await db
              .from('student_fee_assessments')
              .select('id')
              .eq('school_id', schoolId)
              .eq('student_id', studentId)
              .eq('term', term)
              .isFilter('academic_year_id', null)
              .maybeSingle()
              .timeout(const Duration(seconds: 5))
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
            .eq('id', existing!['id'])
            .timeout(const Duration(seconds: 5));
      } else {
        await db
            .from('student_fee_assessments')
            .insert(payload)
            .timeout(const Duration(seconds: 5));
      }
    } catch (error) {
      if (!_isNetworkFailure(error)) rethrow;
      await _queueStudentFeeAssessment(
        schoolId: schoolId,
        studentId: studentId,
        term: term,
        totalFee: totalFee,
        discount: discount,
        academicYearId: academicYearId,
        academicYearLabel: academicYearLabel,
        note: note,
      );
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
      await _queueOfflinePayment(
        schoolId: schoolId,
        studentId: studentId,
        amount: amount,
        note: note.trim(),
        term: term,
        feeAssessmentId: feeAssessmentId,
        idempotencyKey: idempotencyKey,
        fingerprint: fingerprint,
      );
      return;
    }

    try {
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
      }).timeout(const Duration(seconds: 5));
      if (result == null || result.toString().isEmpty) {
        throw Exception('لم يؤكد الخادم تسجيل الدفعة.');
      }
    } catch (error) {
      if (!_isNetworkFailure(error)) rethrow;
      await _queueOfflinePayment(
        schoolId: schoolId,
        studentId: studentId,
        amount: amount,
        note: note.trim(),
        term: term,
        feeAssessmentId: feeAssessmentId,
        idempotencyKey: idempotencyKey,
        fingerprint: fingerprint,
      );
      return;
    }

    pending.remove(fingerprint);
    if (pending.isEmpty) {
      await secureStorage.delete(key: pendingKey);
    } else {
      await secureStorage.write(key: pendingKey, value: jsonEncode(pending));
    }
  }

  /// Creates an encrypted-device-cache snapshot without contacting Supabase.
  /// It intentionally includes only data already persisted in this device's
  /// secure cache and the pending write queue; it is not a fresh server export.
  Future<Map<String, dynamic>> exportCachedBackup() async {
    final userId = await _userId();
    if (userId == null || userId.isEmpty) {
      throw Exception('لا توجد هوية مدرسة محفوظة محلياً لهذا الجهاز.');
    }
    final profile = await cachedProfileForUser(userId);
    final schoolId = profile?.schoolId;
    if (profile == null || schoolId == null || schoolId.isEmpty) {
      throw Exception('لا توجد بيانات مدرسة محفوظة محلياً لإنشاء النسخة.');
    }
    final school = await cachedSchoolForId(schoolId);
    if (school == null) {
      throw Exception('بيانات المدرسة غير موجودة في التخزين المحلي.');
    }

    const prefix = 'lamin.cache.v1.';
    final allSecureValues = await _cacheStorage.readAll();
    final cachedValues = <String, String>{};
    for (final entry in allSecureValues.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final cacheKey = entry.key.substring(prefix.length);
      final belongsToCurrentUser =
          cacheKey == _profileCacheKey(userId) ||
          cacheKey == 'school_id_cache_$userId';
      final belongsToCurrentSchool =
          cacheKey == _schoolCacheKey(schoolId) ||
          cacheKey.contains(schoolId);
      if (belongsToCurrentUser || belongsToCurrentSchool) {
        cachedValues[cacheKey] = entry.value;
      }
    }

    final pendingOperations = await _readOfflineOperations(schoolId);
    return {
      'format': 'lamin-school-backup-v2',
      'taken_at': DateTime.now().toUtc().toIso8601String(),
      'school_filter': schoolId,
      'local_cache_snapshot': true,
      'local_cache_version': 1,
      'local_user_id': userId,
      'local_cache': cachedValues,
      'pending_offline_operations': pendingOperations,
    };
  }

  /// Restores a cache-only backup to this device. It never writes to Supabase.
  Future<void> restoreCachedSnapshot(Map<String, dynamic> backup) async {
    final userId = await _userId();
    if (userId == null || userId.isEmpty) {
      throw Exception('تعذر تحديد المستخدم الحالي لاستعادة النسخة المحلية.');
    }
    final profile = await cachedProfileForUser(userId);
    final schoolId = profile?.schoolId;
    if (schoolId == null || schoolId.isEmpty ||
        backup['format'] != 'lamin-school-backup-v2' ||
        backup['local_cache_snapshot'] != true ||
        backup['school_filter']?.toString() != schoolId ||
        backup['local_user_id']?.toString() != userId ||
        backup['local_cache'] is! Map) {
      throw Exception('النسخة المحلية لا تطابق المدرسة والمستخدم الحاليين.');
    }

    final cacheValues = Map<String, dynamic>.from(
      backup['local_cache'] as Map,
    );
    const allowedPrefix = 'lamin.cache.v1.';
    for (final entry in cacheValues.entries) {
      final cacheKey = entry.key;
      final belongsToCurrentUser =
          cacheKey == _profileCacheKey(userId) ||
          cacheKey == 'school_id_cache_$userId';
      final belongsToCurrentSchool =
          cacheKey == _schoolCacheKey(schoolId) ||
          cacheKey.contains(schoolId);
      if ((!belongsToCurrentUser && !belongsToCurrentSchool) ||
          entry.value is! String) {
        continue;
      }
      await _cacheStorage.write(
        key: '$allowedPrefix$cacheKey',
        value: entry.value as String,
      );
      await prefs.remove(cacheKey);
    }

    final pending = backup['pending_offline_operations'];
    if (pending is List) {
      const supportedTypes = {
        'create_student',
        'update_student',
        'save_fee',
        'add_payment',
        'attendance',
      };
      final operations = pending
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => supportedTypes.contains(row['type']))
          .toList();
      await _writeOfflineOperations(schoolId, operations);
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
        await _removeCache(cacheKey);
        return null;
      }
      final data = Map<String, dynamic>.from(row);
      await _writeCacheString(cacheKey, jsonEncode(data));
      return data;
    } catch (_) {
      final raw = await _readCacheString(cacheKey);
      if (raw == null) return null;
      try {
        return Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        await _removeCache(cacheKey);
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
    await db.from('school_branding').upsert(payload)
        .timeout(const Duration(seconds: 5));
    await _writeCacheString(
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
    await db.from('school_branding').delete().eq('school_id', schoolId)
        .timeout(const Duration(seconds: 5));
    await _removeCache(_tenantCacheKey(schoolId, 'school_branding'));
  }

  Future<void> deleteSchoolUser(String userId) async {
    await db.rpc('delete_school_user', params: {'p_user_id': userId})
        .timeout(const Duration(seconds: 5));
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
    }).timeout(const Duration(seconds: 5));
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
    }).timeout(const Duration(seconds: 5));
  }

  Future<void> signOut() => db.auth.signOut();
}