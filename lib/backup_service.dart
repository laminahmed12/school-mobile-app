import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'local_backup_crypto.dart';
import 'repository.dart';

class DriveBackupResult {
  final String accountEmail;
  final String fileId;

  const DriveBackupResult({required this.accountEmail, required this.fileId});
}

class BackupService {
  static const String _localBackupKeyName =
      'lamin.local_backup.encryption_key.v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<SecretKey> _localBackupKey() async {
    final stored = await _secureStorage.read(key: _localBackupKeyName);
    if (stored != null && stored.isNotEmpty) {
      try {
        final bytes = base64Decode(stored);
        if (bytes.length != 32) {
          throw const FormatException('Invalid local backup encryption key.');
        }
        return SecretKey(bytes);
      } catch (_) {
        throw Exception(
          'تعذر قراءة مفتاح تشفير النسخ المحلية. لم تُحذف النسخ الموجودة.',
        );
      }
    }

    final generated = await AesGcm.with256bits().newSecretKey();
    final bytes = await generated.extractBytes();
    if (bytes.length != 32) {
      throw Exception('تعذر إنشاء مفتاح تشفير صالح للنسخ المحلية.');
    }
    await _secureStorage.write(
      key: _localBackupKeyName,
      value: base64Encode(bytes),
    );
    return SecretKey(bytes);
  }

  static Future<File> _writeEncryptedLocalBackup({
    required String path,
    required String clearText,
    required String schoolId,
  }) async {
    final key = await _localBackupKey();
    final encrypted = await LocalBackupCrypto.encryptText(
      clearText: clearText,
      key: key,
      schoolId: schoolId,
    );
    final target = File(path);
    final temporary = File('$path.tmp');
    await temporary.writeAsString(jsonEncode(encrypted), flush: true);

    // Verify authentication and the school binding before replacing any
    // previously saved backup. This also detects incomplete writes.
    final verificationEnvelope = Map<String, dynamic>.from(
      jsonDecode(await temporary.readAsString()) as Map,
    );
    final verified = await LocalBackupCrypto.decryptText(
      envelope: verificationEnvelope,
      key: key,
      expectedSchoolId: schoolId,
    );
    if (verified != clearText) {
      await temporary.delete();
      throw Exception('تعذر التحقق من النسخة الاحتياطية المشفرة.');
    }
    if (await target.exists()) await target.delete();
    return temporary.rename(path);
  }

  /// Validates both the outer backup envelope and the school-scoped RPC payload.
  /// This is enforced in the service layer as well as in the UI.
  static Map<String, dynamic> validateBackupEnvelope(
    dynamic decoded, {
    required String expectedSchoolId,
  }) {
    if (decoded is! Map) {
      throw Exception('تنسيق ملف النسخة الاحتياطية غير صالح.');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['format'] != 'lamin-school-backup' ||
        envelope['version'] != 2 ||
        envelope['school_id']?.toString() != expectedSchoolId ||
        envelope['data'] is! Map) {
      throw Exception(
        'النسخة الاحتياطية لا تطابق المدرسة الحالية أو أن تنسيقها غير مدعوم.',
      );
    }
    final data = Map<String, dynamic>.from(envelope['data'] as Map);
    if (data['format'] != 'lamin-school-backup-v2' ||
        data['school_filter']?.toString() != expectedSchoolId) {
      throw Exception('محتوى النسخة الاحتياطية لا يطابق المدرسة الحالية.');
    }
    envelope['data'] = data;
    return envelope;
  }

  static Future<File> createLocalBackup(SchoolRepository repo) async {
    final data = await repo.exportBackup();
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/LaameenBackups');
    if (!await backups.exists()) await backups.create(recursive: true);
    final year = await repo.activeAcademicYearName() ?? 'current';
    final school = await repo.school();
    final schoolId = school?['id']?.toString();
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة؛ لم تُنشأ نسخة احتياطية غير مرتبطة بمدرسة.');
    }
    final safeYear = year.replaceAll(
      RegExp(r'[^0-9A-Za-z\\u0600-\\u06FF_-]+'),
      '_',
    );
    final baseName = 'lamin_${safeYear}_${schoolId}';
    final legacyFile = File('${backups.path}/$baseName.json');
    final encryptedFile = File('${backups.path}/$baseName.enc');
    final envelope = {
      'format': 'lamin-school-backup',
      'version': 2,
      'school_id': schoolId,
      'school_code': school?['code'],
      'school_name': school?['name'],
      'academic_year': year,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
    final clearText = const JsonEncoder.withIndent('  ').convert(envelope);
    final saved = await _writeEncryptedLocalBackup(
      path: encryptedFile.path,
      clearText: clearText,
      schoolId: schoolId,
    );
    if (await legacyFile.exists()) await legacyFile.delete();
    return saved;
  }

  static Future<Map<String, dynamic>?> readLatestLocalBackup(
    SchoolRepository repo,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/LaameenBackups');
    if (!await backups.exists()) return null;
    final school = await repo.school();
    final schoolId = school?['id']?.toString();
    if (schoolId == null || schoolId.isEmpty) return null;

    final files = await backups
        .list()
        .where(
          (entry) =>
              entry is File &&
              (entry.path.endsWith('_${schoolId}.enc') ||
                  entry.path.endsWith('_${schoolId}.json')),
        )
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    final selected = files.first;
    final raw = await selected.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw Exception('ملف النسخة الاحتياطية المحلية غير صالح.');
    }
    final map = Map<String, dynamic>.from(decoded);

    if (map['format'] == LocalBackupCrypto.format) {
      final clearText = await LocalBackupCrypto.decryptText(
        envelope: map,
        key: await _localBackupKey(),
        expectedSchoolId: schoolId,
      );
      return validateBackupEnvelope(
        jsonDecode(clearText),
        expectedSchoolId: schoolId,
      );
    }

    // Older releases stored local backups as clear JSON. Validate the tenant
    // before encrypting and removing that legacy file.
    final validated = validateBackupEnvelope(
      map,
      expectedSchoolId: schoolId,
    );
    final encryptedPath = selected.path.endsWith('.json')
        ? '${selected.path.substring(0, selected.path.length - 5)}.enc'
        : '${selected.path}.enc';
    final migrated = await _writeEncryptedLocalBackup(
      path: encryptedPath,
      clearText: raw,
      schoolId: schoolId,
    );
    final migratedContent = await migrated.readAsString();
    final migratedEnvelope = Map<String, dynamic>.from(
      jsonDecode(migratedContent) as Map,
    );
    final verifiedClearText = await LocalBackupCrypto.decryptText(
      envelope: migratedEnvelope,
      key: await _localBackupKey(),
      expectedSchoolId: schoolId,
    );
    validateBackupEnvelope(
      jsonDecode(verifiedClearText),
      expectedSchoolId: schoolId,
    );
    if (selected.existsSync()) await selected.delete();
    return validated;
  }

  static Future<Map<String, dynamic>?> pickBackupFile({
    required String expectedSchoolId,
  }) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty) return null;
    final file = selection.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('تعذر قراءة ملف النسخة الاحتياطية.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    return validateBackupEnvelope(decoded, expectedSchoolId: expectedSchoolId);
  }

  static bool _googleSignInInitialized = false;
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Uploads the generated backup directly to the signed-in user's Google Drive.
  /// Uses the narrow drive.file scope and updates this app's existing backup
  /// for the same school/year rather than creating a duplicate on every run.
  static Future<DriveBackupResult?> backupAndSave(
    SchoolRepository repo, {
    required Future<bool> Function(String accountEmail) confirmAccount,
  }) async {
    final data = await repo.exportBackup();
    final school = await repo.school();
    final schoolId = school?['id']?.toString() ?? 'unknown-school';
    final year = await repo.activeAcademicYearName() ?? 'current';
    final safeYear = year.replaceAll(
      RegExp(r'[^0-9A-Za-z\u0600-\u06FF_-]+'),
      '_',
    );
    final fileName = 'lamin_${safeYear}_${schoolId}.json';
    final envelope = {
      'format': 'lamin-school-backup',
      'version': 2,
      'school_id': schoolId,
      'school_code': school?['code'],
      'school_name': school?['name'],
      'academic_year': year,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(envelope),
    );

    var stage = 'initialize';
    try {
      final signIn = GoogleSignIn.instance;
      if (_googleServerClientId.trim().isEmpty) {
        throw Exception(
          'تكامل Google Drive غير مهيأ: يلزم ضبط GOOGLE_SERVER_CLIENT_ID في إعدادات بناء التطبيق.',
        );
      }
      if (!_googleSignInInitialized) {
        stage = 'initialize';
        await signIn.initialize(serverClientId: _googleServerClientId);
        _googleSignInInitialized = true;
      }

      // Do not sign out immediately before interactive authentication.
      // Forcing sign-out here can trigger Google account reauthentication
      // failures on Android; authenticate directly and let Google handle the
      // account/session state.
      stage = 'authenticate';
      final account = await signIn.authenticate();
      final accountEmail = account.email.trim();
      if (accountEmail.isEmpty) {
        throw Exception(
          'تعذر التحقق من حساب Google الذي اختير للنسخ الاحتياطي.',
        );
      }
      stage = 'confirm_account';
      final accountConfirmed = await confirmAccount(accountEmail);
      if (!accountConfirmed) return null;
      stage = 'authorize_drive_scope';
      final authorization = await account.authorizationClient.authorizeScopes(
        const ['https://www.googleapis.com/auth/drive.file'],
      );
      final token = authorization.accessToken;
      if (token.isEmpty) {
        throw Exception(
          'لم يمنح حساب Google صلاحية الوصول إلى ملف النسخة الاحتياطية.',
        );
      }
      final headers = {'Authorization': 'Bearer $token'};
      final escapedName = fileName
          .replaceAll(r'\', r'\\')
          .replaceAll("'", r"\'");
      final query = "name = '$escapedName' and trashed = false";
      final searchUri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': query,
        'pageSize': '1',
        'orderBy': 'modifiedTime desc',
        'fields': 'files(id,name,webViewLink)',
      });
      stage = 'drive_search';
      final searchResponse = await http.get(searchUri, headers: headers);
      if (searchResponse.statusCode != 200) {
        throw Exception(
          _driveError(searchResponse.statusCode, searchResponse.body),
        );
      }
      final searchJson =
          jsonDecode(searchResponse.body) as Map<String, dynamic>;
      final files = searchJson['files'] as List<dynamic>? ?? const [];
      late final http.Response uploadResponse;

      if (files.isNotEmpty && files.first is Map) {
        final existing = Map<String, dynamic>.from(files.first as Map);
        final id = existing['id']?.toString();
        if (id == null || id.isEmpty) {
          throw Exception('تعذر تحديد ملف النسخة الاحتياطية الموجود في Drive.');
        }
        final updateUri = Uri.https(
          'www.googleapis.com',
          '/upload/drive/v3/files/$id',
          {'uploadType': 'media', 'fields': 'id,name,webViewLink'},
        );
        stage = 'drive_update_upload';
        uploadResponse = await http.patch(
          updateUri,
          headers: {
            ...headers,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: bytes,
        );
      } else {
        final boundary =
            'lamin_backup_${DateTime.now().microsecondsSinceEpoch}';
        final metadata = jsonEncode({
          'name': fileName,
          'mimeType': 'application/json',
          'description': 'Lamīn school backup; school_id=$schoolId; year=$year',
        });
        final prefix = utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n',
        );
        final suffix = utf8.encode('\r\n--$boundary--\r\n');
        final body = <int>[...prefix, ...bytes, ...suffix];
        final createUri = Uri.https(
          'www.googleapis.com',
          '/upload/drive/v3/files',
          {'uploadType': 'multipart', 'fields': 'id,name,webViewLink'},
        );
        stage = 'drive_create_upload';
        uploadResponse = await http.post(
          createUri,
          headers: {
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body,
        );
      }

      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw Exception(
          _driveError(uploadResponse.statusCode, uploadResponse.body),
        );
      }
      final result = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
      final fileId = result['id']?.toString();
      if (fileId == null || fileId.isEmpty) {
        throw Exception('لم يؤكد Google Drive حفظ ملف النسخة الاحتياطية.');
      }
      return DriveBackupResult(accountEmail: accountEmail, fileId: fileId);
    } catch (error, stackTrace) {
      debugPrint('LAMIN_DRIVE_DIAGNOSTIC stage=$stage error=$error');
      debugPrintStack(stackTrace: stackTrace);
      if (error.toString().contains('Account reauth failed')) {
        throw Exception(
          'مرحلة التشخيص: $stage. أعاد Google الخطأ [16] Account reauth failed أثناء المصادقة. '
          'هذا الخطأ لا يحدد السبب وحده؛ أكثر أسباب إعداد OAuth شيوعًا هي عدم تطابق بصمة SHA-1 لشهادة APK المثبّت، '
          'أو اسم الحزمة، أو Web Client ID. لا تُرسل أي رموز دخول أو أسرار.',
        );
      }
      rethrow;
    } finally {
      // Clear Credential Manager's cached Google account relationship after
      // each Drive operation. Re-authenticating without signOut can fail with
      // [16] Account reauth failed on subsequent attempts on Android.
      if (_googleSignInInitialized) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (cleanupError) {
          debugPrint('LAMIN_DRIVE_SIGNOUT_CLEANUP error=$cleanupError');
        }
      }
    }
  }

  /// Downloads the current school's backup from the selected Google Drive account.
  static Future<Map<String, dynamic>?> restoreFromGoogleDrive(
    SchoolRepository repo, {
    required Future<bool> Function(String accountEmail) confirmAccount,
  }) async {
    final school = await repo.school();
    final schoolId = school?['id']?.toString();
    if (schoolId == null || schoolId.isEmpty) {
      throw Exception('تعذر تحديد المدرسة الحالية.');
    }
    final year = await repo.activeAcademicYearName() ?? 'current';
    final safeYear = year.replaceAll(
      RegExp(r'[^0-9A-Za-z\u0600-\u06FF_-]+'),
      '_',
    );
    final fileName = 'lamin_${safeYear}_${schoolId}.json';

    var stage = 'initialize';
    try {
      final signIn = GoogleSignIn.instance;
      if (_googleServerClientId.trim().isEmpty) {
        throw Exception(
          'تكامل Google Drive غير مهيأ: يلزم ضبط GOOGLE_SERVER_CLIENT_ID.',
        );
      }
      if (!_googleSignInInitialized) {
        stage = 'initialize';
        await signIn.initialize(serverClientId: _googleServerClientId);
        _googleSignInInitialized = true;
      }
      // Do not sign out immediately before interactive authentication.
      // Forcing sign-out here can trigger Google account reauthentication
      // failures on Android; authenticate directly and let Google handle the
      // account/session state.
      stage = 'authenticate';
      final account = await signIn.authenticate();
      final accountEmail = account.email.trim();
      if (accountEmail.isEmpty) {
        throw Exception('تعذر التحقق من حساب Google المختار.');
      }
      if (!await confirmAccount(accountEmail)) return null;
      stage = 'authorize_drive_scope';
      final authorization = await account.authorizationClient.authorizeScopes(
        const ['https://www.googleapis.com/auth/drive.file'],
      );
      final token = authorization.accessToken;
      if (token.isEmpty)
        throw Exception('لم يمنح Google صلاحية قراءة النسخة الاحتياطية.');
      final headers = {'Authorization': 'Bearer $token'};
      final escapedName = fileName
          .replaceAll(r'\\', r'\\\\')
          .replaceAll("'", r"\\'");
      final query = "name = '$escapedName' and trashed = false";
      final searchUri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': query,
        'pageSize': '10',
        'orderBy': 'modifiedTime desc',
        'fields': 'files(id,name,mimeType,modifiedTime)',
      });
      stage = 'drive_search';
      final searchResponse = await http.get(searchUri, headers: headers);
      if (searchResponse.statusCode != 200) {
        throw Exception(
          _driveError(searchResponse.statusCode, searchResponse.body),
        );
      }
      final files =
          (jsonDecode(searchResponse.body) as Map<String, dynamic>)['files']
              as List<dynamic>? ??
          const [];
      if (files.isEmpty) {
        throw Exception(
          'لم نعثر على نسخة لهذه المدرسة في حساب Google Drive المختار. تأكد من استخدام الحساب نفسه الذي رُفعت إليه النسخة.',
        );
      }
      final matching = files.where((entry) {
        if (entry is! Map) return false;
        final mime = entry['mimeType']?.toString();
        return mime == 'application/json' || mime == 'application/octet-stream';
      }).toList();
      if (matching.isEmpty)
        throw Exception('عُثر على اسم النسخة لكن نوع الملف غير مدعوم.');
      final id = (matching.first as Map)['id']?.toString();
      if (id == null || id.isEmpty)
        throw Exception('تعذر تحديد ملف النسخة الاحتياطية في Drive.');
      final downloadUri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/$id',
        {'alt': 'media'},
      );
      stage = 'drive_download';
      final downloadResponse = await http.get(downloadUri, headers: headers);
      if (downloadResponse.statusCode != 200) {
        throw Exception(
          _driveError(downloadResponse.statusCode, downloadResponse.body),
        );
      }
      final decoded = jsonDecode(utf8.decode(downloadResponse.bodyBytes));
      return validateBackupEnvelope(decoded, expectedSchoolId: schoolId);
    } catch (error, stackTrace) {
      debugPrint('LAMIN_DRIVE_DIAGNOSTIC stage=$stage error=$error');
      debugPrintStack(stackTrace: stackTrace);
      if (error.toString().contains('Account reauth failed')) {
        throw Exception(
          'مرحلة التشخيص: $stage. أعاد Google الخطأ [16] Account reauth failed أثناء المصادقة. '
          'هذا الخطأ لا يحدد السبب وحده؛ أكثر أسباب إعداد OAuth شيوعًا هي عدم تطابق بصمة SHA-1 لشهادة APK المثبّت، '
          'أو اسم الحزمة، أو Web Client ID. لا تُرسل أي رموز دخول أو أسرار.',
        );
      }
      rethrow;
    } finally {
      // Match upload cleanup so the next restore starts with a clean Google
      // authentication state instead of reusing a stale Credential Manager session.
      if (_googleSignInInitialized) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (cleanupError) {
          debugPrint('LAMIN_DRIVE_SIGNOUT_CLEANUP error=$cleanupError');
        }
      }
    }
  }

  static String _driveError(int statusCode, String body) {
    String? detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) detail = error['message']?.toString();
      }
    } catch (_) {}
    if (statusCode == 401 || statusCode == 403) {
      return 'رفض Google Drive الوصول (HTTP $statusCode). تحقق من إعداد OAuth وتفعيل Google Drive API.'
          '${detail == null ? '' : ' التفاصيل: $detail'}';
    }
    return 'فشل رفع النسخة إلى Google Drive (HTTP $statusCode).'
        '${detail == null ? '' : ' التفاصيل: $detail'}';
  }
}
