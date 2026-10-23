import 'package:flutter/material.dart';
import 'backup_service.dart';
import 'repository.dart';

class BackupView extends StatelessWidget {
  final SchoolRepository repo;
  final Future<void> Function() onChanged;
  const BackupView({super.key, required this.repo, required this.onChanged});

  void _message(BuildContext context, String text, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _local(BuildContext context) async {
    try {
      await BackupService.createLocalBackup(repo);
      _message(
        context,
        'تم إنشاء النسخة المحلية داخل مساحة التطبيق على هذا الجهاز.',
      );
    } catch (e) {
      _message(context, 'تعذر إنشاء النسخة المحلية: $e', error: true);
    }
  }

  Future<void> _external(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حفظ نسخة خارج التطبيق'),
        content: const Text(
          'سجّل الدخول باستخدام حساب Google Drive الخاص بهذه المدرسة، وليس حساب مدرسة أخرى. سيطلب التطبيق صلاحية الوصول إلى ملفات النسخ الاحتياطية التي ينشئها لامين، ثم يرفع الملف مباشرة إلى Drive هذا الحساب. لن يُستخدم حساب مركزي تابع إلى لامين.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('المتابعة إلى Google Drive'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    try {
      final result = await BackupService.backupAndSave(
        repo,
        confirmAccount: (accountEmail) async {
          if (!context.mounted) return false;
          final school = await repo.school();
          final schoolName = school?['name']?.toString() ?? 'المدرسة الحالية';
          if (!context.mounted) return false;
          return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد حساب النسخ الاحتياطي'),
                  content: Text(
                    'المدرسة: $schoolName\n\n'
                    'سيتم رفع النسخة إلى حساب Google Drive التالي:\n$accountEmail\n\n'
                    'تأكد أن هذا هو الحساب المملوك لهذه المدرسة، وليس حساب مدرسة أخرى.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء — يمكنك إعادة المحاولة لاختيار الحساب الصحيح'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد ورفع النسخة'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
      );
      if (result != null && context.mounted) {
        _message(
          context,
          'تم رفع النسخة الاحتياطية إلى Google Drive للحساب: ${result.accountEmail}',
        );
      }
    } catch (e) {
      _message(context, 'تعذر إنشاء ملف النسخة: $e', error: true);
    }
  }

  Future<void> _restoreLocal(BuildContext context) async {
    try {
      final envelope = await BackupService.readLatestLocalBackup(repo);
      if (envelope == null || !context.mounted) {
        _message(
          context,
          'لا توجد نسخة محلية محفوظة لهذه المدرسة على هذا الجهاز.',
        );
        return;
      }
      final school = await repo.school();
      final schoolId = school?['id']?.toString();
      if (schoolId == null || envelope['school_id']?.toString() != schoolId) {
        throw Exception(
          'هذه النسخة تخص مدرسة أخرى. لن تُستعاد لحماية البيانات.',
        );
      }
      final data = Map<String, dynamic>.from(envelope['data'] as Map);
      if (data['format'] != 'lamin-school-backup-v2' ||
          data['school_filter']?.toString() != schoolId) {
        throw Exception('محتوى النسخة المحلية لا يطابق المدرسة الحالية.');
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد استعادة النسخة المحلية'),
          content: const Text(
            'ستُدمج السجلات الموجودة في النسخة مع بيانات المدرسة الحالية دون حذف السجلات الحالية أو استبدالها. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final result = await repo.restoreBackup(data);
      await onChanged();
      _message(
        context,
        'اكتملت الاستعادة المحلية. ${result['message'] ?? 'تم دمج السجلات المتاحة.'}',
      );
    } catch (e) {
      _message(context, 'تعذرت استعادة النسخة المحلية: $e', error: true);
    }
  }

  Future<void> _restoreFile(BuildContext context) async {
    try {
      final envelope = await BackupService.pickBackupFile();
      if (envelope == null || !context.mounted) return;
      final school = await repo.school();
      final schoolId = school?['id']?.toString();
      if (schoolId == null || envelope['school_id']?.toString() != schoolId) {
        throw Exception(
          'هذه النسخة تخص مدرسة أخرى أو بيئة مختلفة. لن تُستعاد لحماية البيانات.',
        );
      }
      final data = Map<String, dynamic>.from(envelope['data'] as Map);
      if (data['format'] != 'lamin-school-backup-v2' ||
          data['school_filter']?.toString() != schoolId) {
        throw Exception('محتوى النسخة لا يطابق المدرسة الحالية.');
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد استعادة البيانات'),
          content: Text(
            'النسخة: ${envelope['school_name'] ?? 'المدرسة'}\n'
            'التاريخ: ${envelope['created_at'] ?? 'غير معروف'}\n\n'
            'ستُدمج السجلات الناقصة من النسخة مع البيانات الحالية. لن تُحذف السجلات الحالية، ولن تُستبدل السجلات المتطابقة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final result = await repo.restoreBackup(data);
      await onChanged();
      _message(
        context,
        'اكتملت الاستعادة الآمنة. ${result['message'] ?? 'تم دمج السجلات المتاحة.'}',
      );
    } catch (e) {
      _message(context, 'تعذرت استعادة النسخة الاحتياطية: $e', error: true);
    }
  }

  Future<void> _restoreDrive(BuildContext context) async {
    try {
      final envelope = await BackupService.restoreFromGoogleDrive(
        repo,
        confirmAccount: (accountEmail) async {
          if (!context.mounted) return false;
          final school = await repo.school();
          final schoolName = school?['name']?.toString() ?? 'المدرسة الحالية';
          if (!context.mounted) return false;
          return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد حساب استعادة النسخة'),
                  content: Text('المدرسة: $schoolName\\n\\nسيتم البحث عن النسخة الاحتياطية في حساب Google Drive التالي:\\n$accountEmail\\n\\nيجب اختيار الحساب الذي حُفظت فيه نسخة هذه المدرسة.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
                  ],
                ),
              ) ?? false;
        },
      );
      if (envelope == null || !context.mounted) return;
      final school = await repo.school();
      final schoolId = school?['id']?.toString();
      if (schoolId == null || envelope['school_id']?.toString() != schoolId) {
        throw Exception('هذه النسخة تخص مدرسة أخرى. لن تُستعاد لحماية البيانات.');
      }
      final data = Map<String, dynamic>.from(envelope['data'] as Map);
      if (data['format'] != 'lamin-school-backup-v2' ||
          data['school_filter']?.toString() != schoolId) {
        throw Exception('محتوى النسخة لا يطابق المدرسة الحالية.');
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد استعادة نسخة Google Drive'),
          content: Text(
            'المدرسة: ${envelope['school_name'] ?? 'المدرسة'}\\n'
            'تاريخ النسخة: ${envelope['created_at'] ?? 'غير معروف'}\\n\\n'
            'ستُدمج السجلات الناقصة فقط. لن تُحذف السجلات الحالية أو تُستبدل السجلات المتطابقة.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استعادة الآن')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final result = await repo.restoreBackup(data);
      await onChanged();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 42),
          title: const Text('تمت الاستعادة بنجاح'),
          content: Text(result['message']?.toString() ?? 'تم دمج السجلات المتاحة من نسخة Google Drive.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا'))],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red, size: 42),
          title: const Text('فشلت استعادة نسخة Google Drive'),
          content: SelectableText(e.toString().replaceFirst('Exception: ', '')),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التخزين والنسخ الاحتياطي')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('نسخ منفصلة بوضوح'),
            subtitle: Text(
              'النسخة المحلية تحفظ داخل التطبيق على هذا الجهاز. تُرفع النسخة الخارجية إلى حساب Google Drive الذي تسجّل المدرسة الدخول به؛ لكل مدرسة حسابها الخاص، ولا يستخدم لامين حساب Drive مركزيًا.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.save_alt_outlined),
            title: const Text('إنشاء نسخة محلية'),
            subtitle: const Text(
              'حفظ نسخة داخل مساحة التطبيق دون فتح نافذة خارجية',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _local(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('حفظ نسخة خارج التطبيق'),
            subtitle: const Text(
              'تسجيل الدخول إلى Google ورفع النسخة الاحتياطية مباشرة إلى Drive',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _external(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore_page_outlined),
            title: const Text('استعادة النسخة المحلية'),
            subtitle: const Text(
              'دمج أحدث نسخة محفوظة داخل التطبيق مع السجلات الحالية',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _restoreLocal(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_backup_restore_outlined),
            title: const Text('استعادة ملف نسخة احتياطية'),
            subtitle: const Text(
              'اختيار ملف JSON محفوظ على الجهاز أو في التخزين السحابي',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _restoreFile(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_download_outlined),
            title: const Text('استعادة نسخة من Google Drive'),
            subtitle: const Text(
              'تسجيل الدخول إلى الحساب الذي حُفظت فيه النسخة، ثم تنزيلها واستعادة سجلات المدرسة',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _restoreDrive(context),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'تنبيه: ملف النسخة الاحتياطية الحالي غير مشفر. احتفظ به في مكان موثوق ولا تشاركه مع غير المخولين.',
          ),
        ),
      ],
    ),
  );
}
