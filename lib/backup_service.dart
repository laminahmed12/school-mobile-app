import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'repository.dart';

class BackupService {
  static Future<File> createLocalBackup(SchoolRepository repo) async {
    final data = await repo.exportBackup();
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/LaameenBackups');
    if (!await backups.exists()) await backups.create(recursive: true);
    final year = await repo.activeAcademicYearName() ?? 'current';
    final school = await repo.school();
    final schoolId = school?['id']?.toString() ?? 'unknown-school';
    final safeYear = year.replaceAll(RegExp(r'[^0-9A-Za-z\u0600-\u06FF_-]+'), '_');
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

  /// Opens Android's native save-location picker instead of the share sheet.
  /// The user can choose Google Drive (if available on the device) or another
  /// destination. This avoids accidentally routing a backup into WhatsApp.
  static Future<String?> backupAndSave(SchoolRepository repo) async {
    final file = await createLocalBackup(repo);
    return FilePicker.platform.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية للمدرسة',
      fileName: file.uri.pathSegments.last,
      bytes: await file.readAsBytes(),
    );
  }
}
