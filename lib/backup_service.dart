import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'repository.dart';

class DriveBackupResult {
  final String accountEmail;
  final String fileId;

  const DriveBackupResult({required this.accountEmail, required this.fileId});
}

class BackupService {
  static Future<File> createLocalBackup(SchoolRepository repo) async {
    final data = await repo.exportBackup();
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/LaameenBackups');
    if (!await backups.exists()) await backups.create(recursive: true);
    final year = await repo.activeAcademicYearName() ?? 'current';
    final school = await repo.school();
    final schoolId = school?['id']?.toString() ?? 'unknown-school';
    final safeYear = year.replaceAll(
      RegExp(r'[^0-9A-Za-z\u0600-\u06FF_-]+'),
      '_',
    );
    final file = File('${backups.path}/lamin_${safeYear}_${schoolId}.json');
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
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(envelope),
      flush: true,
    );
    return file;
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
          (entry) => entry is File && entry.path.endsWith('_${schoolId}.json'),
        )
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final decoded = jsonDecode(await files.first.readAsString());
    if (decoded is! Map) throw Exception('تنسيق النسخة المحلية غير صالح.');
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['format'] != 'lamin-school-backup' ||
        envelope['version'] != 2 ||
        envelope['school_id']?.toString() != schoolId ||
        envelope['data'] is! Map) {
      throw Exception('النسخة المحلية لا تطابق المدرسة الحالية.');
    }
    return envelope;
  }

  static Future<Map<String, dynamic>?> pickBackupFile() async {
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
    if (decoded is! Map) {
      throw Exception('تنسيق ملف النسخة الاحتياطية غير صالح.');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['format'] != 'lamin-school-backup' ||
        envelope['version'] != 2) {
      throw Exception('إصدار النسخة الاحتياطية غير مدعوم.');
    }
    if (envelope['data'] is! Map || envelope['school_id'] == null) {
      throw Exception('ملف النسخة الاحتياطية ناقص البيانات.');
    }
    return envelope;
  }

  static bool _googleSignInInitialized = false;
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Uploads the generated backup directly to the signed-in user's Google Drive.
  /// Uses the narrow drive.file scope and updates this app's existing backup
  /// for the same school/year rather than creating a duplicate on every run.
  /// Opens Android's native save-location picker instead of performing
  /// Google OAuth inside the app. The user may choose Google Drive or another
  /// document provider; the returned path is only a save confirmation from
  /// the picker and must not be described as a cloud upload.
  static Future<String?> backupAndSave(SchoolRepository repo) async {
    final data = await repo.exportBackup();
    final school = await repo.school();
    final schoolId = school?['id']?.toString() ?? 'unknown-school';
    final year = await repo.activeAcademicYearName() ?? 'current';
    final safeYear = year.replaceAll(
      RegExp(r'[^0-9A-Za-z\\u0600-\\u06FF_-]+'),
      '_',
    );
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
    return FilePicker.platform.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية في Google Drive أو موقع آخر',
      fileName: 'lamin_${safeYear}_${schoolId}.json',
      bytes: bytes,
    );
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
      if (decoded is! Map)
        throw Exception('محتوى النسخة في Google Drive غير صالح.');
      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['format'] != 'lamin-school-backup' ||
          envelope['version'] != 2 ||
          envelope['school_id']?.toString() != schoolId ||
          envelope['data'] is! Map) {
        throw Exception(
          'النسخة الموجودة في Drive لا تطابق المدرسة الحالية أو أن تنسيقها غير مدعوم.',
        );
      }
      return envelope;
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
