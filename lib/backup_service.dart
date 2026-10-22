import 'dart:convert';
import 'dart:io';

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

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['https://www.googleapis.com/auth/drive.file'],
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

    try {
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return null;
      final accountEmail = account.email.trim();
      if (accountEmail.isEmpty) {
        throw Exception('تعذر التحقق من حساب Google الذي اختير للنسخ الاحتياطي.');
      }
      final accountConfirmed = await confirmAccount(accountEmail);
      if (!accountConfirmed) {
        await _googleSignIn.signOut();
        return null;
      }
      final authentication = await account.authentication;
      final token = authentication.accessToken ?? '';
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
      final searchResponse = await http.get(searchUri, headers: headers);
      if (searchResponse.statusCode != 200) {
        throw Exception(
          _driveError(searchResponse.statusCode, searchResponse.body),
        );
      }
      final searchJson = jsonDecode(searchResponse.body) as Map<String, dynamic>;
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
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('canceled') || message.contains('cancelled')) {
        return null;
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
