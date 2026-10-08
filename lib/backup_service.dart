import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'repository.dart';

class BackupService {
  static Future<File> createLocalBackup(SchoolRepository repo) async {
    final data = await repo.exportBackup();
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(dir.path + '/LaameenBackups');
    if (!await backups.exists()) await backups.create(recursive: true);
    final year = await repo.activeAcademicYearName() ?? 'current';
    final school = await repo.school();
    final schoolId = school?['id']?.toString() ?? 'unknown-school';
    final safeYear = year.replaceAll(RegExp(r'[^0-9A-Za-z\u0600-\u06FF_-]+'), '_');
    final file = File(backups.path + '/lamin_' + safeYear + '_' + schoolId + '.json');
    final envelope = {'format':'lamin-school-backup','version':2,'school_id':schoolId,'school_code':school?['code'],'school_name':school?['name'],'academic_year':year,'created_at':DateTime.now().toUtc().toIso8601String(),'data':data};
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(envelope), flush:true);
    return file;
  }
  static Future<void> backupAndOpenShare(SchoolRepository repo) async {
    final file=await createLocalBackup(repo);
    await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/json')],subject:'نسخة احتياطية لامين',text:'احفظ هذه النسخة داخل OneDrive الخاص بالمدرسة.'));
  }
}
