import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'repository.dart';

class BackupService {
  static Future<File> createLocalBackup(SchoolRepository repo) async {
    final data = await repo.exportBackup();
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/LaameenBackups');
    if (!await backups.exists()) await backups.create(recursive: true);

    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final file = File('${backups.path}/laameen-backup-$stamp.json');
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(pretty, flush: true);
    return file;
  }

  static Future<void> backupAndOpenShare(SchoolRepository repo) async {
    final file = await createLocalBackup(repo);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية لامين',
        text: 'نسخة احتياطية لبيانات المدرسة. اختر OneDrive لحفظها في السحابة، أو احفظها محليًا.',
      ),
    );
  }
}
