import 'package:flutter/material.dart';
import 'supabase_config.dart';

class AcademicRolloverView extends StatefulWidget {
  const AcademicRolloverView({super.key});
  @override
  State<AcademicRolloverView> createState() => _AcademicRolloverViewState();
}

class _AcademicRolloverViewState extends State<AcademicRolloverView> {
  List<Map<String, dynamic>> years = [];
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic>? batch;
  String? sourceYear, targetYear, batchId, error;
  bool loading = true, working = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      years = (await db.from('academic_years').select('id,name,active,is_closed').order('starts_on', ascending: false) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      classes = (await db.from('classes').select('id,name,section,grade_order,academic_year_id').order('grade_order') as List).map((e) => Map<String, dynamic>.from(e)).toList();
      students = (await db.from('students').select('id,name').order('name') as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (sourceYear == null || !years.any((y) => y['id'].toString() == sourceYear)) {
        final active = years.where((y) => y['active'] == true).toList();
        sourceYear = (active.isNotEmpty ? active.first : (years.isNotEmpty ? years.first : null))?['id']?.toString();
      }
      if (targetYear == null || targetYear == sourceYear || !years.any((y) => y['id'].toString() == targetYear && y['is_closed'] != true)) {
        final options = years.where((y) => y['id'].toString() != sourceYear && y['is_closed'] != true).toList();
        targetYear = options.isEmpty ? null : options.first['id'].toString();
      }
      if (batchId != null) await loadBatch();
    } catch (e) { error = 'تعذر تحميل بيانات الترحيل: ' + e.toString(); }
    if (mounted) setState(() => loading = false);
  }

  String studentName(String? id) {
    for (final s in students) { if (s['id']?.toString() == id) return s['name']?.toString() ?? 'طالب'; }
    return 'طالب';
  }

  String yearName(String? id) {
    for (final y in years) { if (y['id']?.toString() == id) return y['name']?.toString() ?? 'سنة'; }
    return 'سنة';
  }

  Future<void> prepare() async {
    if (sourceYear == null || targetYear == null || sourceYear == targetYear) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر سنة مصدر وسنة هدف مختلفتين.')));
      return;
    }
    setState(() => working = true);
    try {
      final result = await db.rpc('prepare_academic_rollover', params: {'p_source_year': sourceYear, 'p_target_year': targetYear});
      batchId = result.toString();
      await loadBatch();
      if (mounted) setState(() {});
    } catch (e) {
      error = 'تعذر إعداد المعاينة: ' + e.toString();
    } finally { if (mounted) setState(() => working = false); }
  }

  Future<void> loadBatch() async {
    if (batchId == null) return;
    final row = await db.from('rollover_batches').select().eq('id', batchId!).maybeSingle();
    batch = row == null ? null : Map<String, dynamic>.from(row);
    items = (await db.from('rollover_items').select().eq('batch_id', batchId!).order('created_at') as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> classOptions(Map<String, dynamic> item, String decision) {
    if (decision != 'promote' && decision != 'repeat') return [];
    final source = classes.where((c) => c['id']?.toString() == item['source_class_id']?.toString()).toList();
    final sourceOrder = (source.isEmpty ? null : source.first['grade_order']) as num?;
    final sourceSection = source.isEmpty ? null : source.first['section']?.toString();
    if (sourceOrder == null) return classes.where((c) => (c['academic_year_id'] == null || c['academic_year_id'].toString() == targetYear)).toList();
    final wanted = sourceOrder.toInt() + (decision == 'promote' ? 1 : 0);
    return classes.where((c) => (c['academic_year_id'] == null || c['academic_year_id'].toString() == targetYear)
      && (c['grade_order'] as num?)?.toInt() == wanted
      && (sourceSection == null || sourceSection.isEmpty || c['section']?.toString() == sourceSection)).toList();
  }

  Future<void> saveDecision(Map<String, dynamic> item) async {
    final decision = item['decision']?.toString() ?? 'exclude';
    final classId = item['target_class_id']?.toString();
    if ((decision == 'promote' || decision == 'repeat') && (classId == null || classId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الصف الهدف قبل تأكيد القرار.')));
      return;
    }
    setState(() => working = true);
    try {
      final userId = db.auth.currentUser?.id;
      await db.from('rollover_items').update({
        'decision': decision, 'target_class_id': (decision == 'promote' || decision == 'repeat') ? classId : null,
        'reviewed': true, 'reviewed_by': userId, 'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', item['id']);
      await loadBatch();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ القرار: ' + e.toString())));
    } finally { if (mounted) setState(() => working = false); }
  }

  Future<void> execute() async {
    if (items.any((i) => i['reviewed'] != true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تأكيد قرار كل طالب أولاً.')));
      return;
    }
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('اعتماد الترحيل النهائي'),
      content: Text('سيتم ترحيل الطلاب والأرصدة المعتمدة، ثم إقفال سنة ' + yearName(sourceYear) + ' وتفعيل سنة ' + yearName(targetYear) + '. العملية ذرية وتحفظ السجلات التاريخية. هل تعتمد التنفيذ؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('مراجعة لاحقًا')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد وتنفيذ'))],
    )) ?? false;
    if (!yes) return;
    setState(() => working = true);
    try {
      final result = await db.rpc('execute_academic_rollover', params: {'p_batch_id': batchId});
      await loadBatch();
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result is Map ? (result['message']?.toString() ?? 'اكتمل الترحيل.') : 'اكتمل الترحيل.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لم يكتمل الترحيل: ' + e.toString())));
      await loadBatch();
    } finally { if (mounted) setState(() => working = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إقفال السنة وترحيل الطلاب'), actions: [IconButton(onPressed: loading || working ? null : load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: const Color(0xFF155D4A), child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('راجع قبل أن تعتمد', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('لا تُقفل السنة ولا تُرحّل الأرصدة قبل تأكيد قرار كل طالب. الديون المرحّلة ترتبط بالسنة المصدر وتُنشأ مرة واحدة.', style: TextStyle(color: Colors.white)),
      ]))),
      if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(error!))),
      if (years.length < 2) const Card(child: ListTile(title: Text('يلزم وجود سنتين دراسيتين'), subtitle: Text('أضف السنة الهدف من إعدادات المدرسة قبل إعداد الترحيل.'))),
      if (years.length >= 2) ...[
        DropdownButtonFormField<String>(value: sourceYear, decoration: const InputDecoration(labelText: 'السنة المصدر'),
          items: years.map((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['name'].toString() + (y['active'] == true ? ' • نشطة' : '')))).toList(),
          onChanged: working ? null : (v) => setState(() { sourceYear = v; if (targetYear == v) targetYear = null; })),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: targetYear, decoration: const InputDecoration(labelText: 'السنة الهدف'),
          items: years.where((y) => y['id'].toString() != sourceYear && y['is_closed'] != true).map((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['name'].toString()))).toList(),
          onChanged: working ? null : (v) => setState(() => targetYear = v)),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: working ? null : prepare, icon: const Icon(Icons.fact_check_outlined), label: Text(working ? 'جار الإعداد...' : 'إعداد المعاينة')),
      ],
      if (batch != null) ...[
        Card(child: ListTile(leading: const Icon(Icons.summarize_outlined), title: Text(yearName(batch!['source_academic_year_id']?.toString()) + ' ← ' + yearName(batch!['target_academic_year_id']?.toString())),
          subtitle: Text('الحالة: ' + batch!['status'].toString() + ' • الطلاب: ' + items.length.toString() + ' • بانتظار المراجعة: ' + items.where((i) => i['reviewed'] != true).length.toString() +
            ' • الأرصدة: ' + items.fold<double>(0, (v, i) => v + ((i['source_balance'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2) + ' د.ل'))),
        if (batch!['status'] == 'completed') const Card(child: ListTile(leading: Icon(Icons.verified, color: Colors.green), title: Text('اكتمل الترحيل'), subtitle: Text('تم الاحتفاظ بسجلات السنة المصدر.'))),
        ...items.map((item) {
          final decision = item['decision']?.toString() ?? 'exclude';
          final options = classOptions(item, decision);
          final currentClass = item['target_class_id']?.toString();
          final validClass = options.any((c) => c['id']?.toString() == currentClass);
          final selectedClass = validClass ? currentClass : null;
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(child: Text(item['reviewed'] == true ? '✓' : '!')),
              const SizedBox(width: 10),
              Expanded(child: Text(studentName(item['student_id']?.toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Text(((item['source_balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2) + ' د.ل'),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(value: decision, decoration: const InputDecoration(labelText: 'قرار الطالب'),
              items: const [
                DropdownMenuItem(value: 'promote', child: Text('ناجح - ينتقل للصف التالي')),
                DropdownMenuItem(value: 'repeat', child: Text('راسب - يعيد الصف نفسه')),
                DropdownMenuItem(value: 'graduate', child: Text('خريج - أرشفة')),
                DropdownMenuItem(value: 'transfer', child: Text('منقول - أرشفة')),
                DropdownMenuItem(value: 'exclude', child: Text('استبعاد من الترحيل')),
              ],
              onChanged: working || batch!['status'] == 'completed' ? null : (v) {
                if (v == null) return;
                final targets = classOptions(item, v);
                setState(() { item['decision'] = v; item['target_class_id'] = targets.isEmpty ? null : targets.first['id'].toString(); item['reviewed'] = false; });
              }),
            if (decision == 'promote' || decision == 'repeat') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: selectedClass, decoration: const InputDecoration(labelText: 'الصف الهدف'),
                items: options.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'].toString() + (c['section']?.toString().isNotEmpty == true ? ' • ' + c['section'].toString() : '')))).toList(),
                onChanged: working || batch!['status'] == 'completed' ? null : (v) => setState(() { item['target_class_id'] = v; item['reviewed'] = false; })),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: working || batch!['status'] == 'completed' ? null : () => saveDecision(item), icon: const Icon(Icons.fact_check), label: Text(item['reviewed'] == true ? 'القرار مؤكد - اضغط للحفظ بعد أي تعديل' : 'تأكيد قرار هذا الطالب')),
          ])));
        }),
        if (batch!['status'] != 'completed') FilledButton.icon(onPressed: working || items.isEmpty ? null : execute, icon: const Icon(Icons.lock_clock), label: Text(working ? 'جار التنفيذ...' : 'اعتماد الترحيل وإقفال السنة')),
      ],
      const SizedBox(height: 90),
    ])),
  );
}
