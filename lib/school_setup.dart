import 'package:flutter/material.dart';
import 'repository.dart';
import 'models.dart';

class SchoolSetupView extends StatefulWidget {
  final SchoolRepository repo;
  const SchoolSetupView({super.key, required this.repo});
  @override State<SchoolSetupView> createState() => _SchoolSetupViewState();
}

class _SchoolSetupViewState extends State<SchoolSetupView> {
  List<Map<String, dynamic>> years = [];
  List<Map<String, dynamic>> classes = [];
  List<SubjectItem> subjects = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      await widget.repo.ensureOwnerSchool();
      years = await widget.repo.academicYears();
      classes = await widget.repo.classes();
      subjects = await widget.repo.subjects();
    } catch (e) {
      error = 'تعذر تحميل إعدادات المدرسة. تحقق من الاتصال ثم أعد المحاولة.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد المدرسة'),
        actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 46),
                  const SizedBox(height: 12),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                ])))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(child: ListTile(
                        leading: const Icon(Icons.event),
                        title: const Text('السنوات الدراسية'),
                        subtitle: Text('${years.length} سنة'),
                        trailing: IconButton(onPressed: () => addYear(c), icon: const Icon(Icons.add)),
                      )),
                      ...years.map((y) => ListTile(
                        title: Text('${y['name']}'),
                        subtitle: Text(y['active'] == true ? 'نشطة' : 'غير نشطة'),
                      )),
                      Card(child: ListTile(
                        leading: const Icon(Icons.class_),
                        title: const Text('الصفوف والفصول'),
                        subtitle: Text('${classes.length} صف/فصل'),
                        trailing: IconButton(onPressed: () => addClass(c), icon: const Icon(Icons.add)),
                      )),
                      ...classes.map((x) => ListTile(title: Text('${x['name']}'), subtitle: Text('${x['section'] ?? ''}'))),
                      Card(child: ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: const Text('المواد الدراسية'),
                        subtitle: Text('${subjects.length} مادة'),
                        trailing: IconButton(onPressed: () => addSubject(c), icon: const Icon(Icons.add)),
                      )),
                      ...subjects.map((s) => ListTile(
                        leading: const Icon(Icons.book_outlined),
                        title: Text(s.name),
                      )),
                    ],
                  ),
                ),
    );
  }

  Future<void> addYear(BuildContext c) async {
    final t = TextEditingController();
    await showDialog(context: c, builder: (dialog) => AlertDialog(
      title: const Text('سنة دراسية'),
      content: TextField(controller: t, decoration: const InputDecoration(labelText: 'مثال: 2026 / 2027')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (t.text.trim().isEmpty) return;
          try { await widget.repo.addAcademicYear(t.text); if (dialog.mounted) Navigator.pop(dialog); await load(); }
          catch (_) { if (dialog.mounted) ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(content: Text('تعذر حفظ السنة الدراسية'))); }
        }, child: const Text('حفظ')),
      ],
    ));
  }

  Future<void> addClass(BuildContext c) async {
    final n = TextEditingController(), s = TextEditingController();
    await showDialog(context: c, builder: (dialog) => AlertDialog(
      title: const Text('صف / فصل'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'الصف')),
        TextField(controller: s, decoration: const InputDecoration(labelText: 'الفصل / الشعبة')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (n.text.trim().isEmpty) return;
          try { await widget.repo.addClass(name: n.text, section: s.text); if (dialog.mounted) Navigator.pop(dialog); await load(); }
          catch (_) { if (dialog.mounted) ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(content: Text('تعذر حفظ الصف'))); }
        }, child: const Text('حفظ')),
      ],
    ));
  }

  Future<void> addSubject(BuildContext c) async {
    final t = TextEditingController();
    await showDialog(context: c, builder: (dialog) => AlertDialog(
      title: const Text('مادة دراسية'),
      content: TextField(controller: t, decoration: const InputDecoration(labelText: 'اسم المادة')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (t.text.trim().isEmpty) return;
          try { await widget.repo.addSubject(t.text); if (dialog.mounted) Navigator.pop(dialog); await load(); }
          catch (_) { if (dialog.mounted) ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(content: Text('تعذر حفظ المادة'))); }
        }, child: const Text('حفظ')),
      ],
    ));
  }
}
