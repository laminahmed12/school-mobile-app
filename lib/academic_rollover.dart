import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'repository.dart';

class AcademicRolloverView extends StatefulWidget {
  final SchoolRepository repo;
  const AcademicRolloverView({super.key, required this.repo});

  @override
  State<AcademicRolloverView> createState() => _AcademicRolloverViewState();
}

class _AcademicRolloverViewState extends State<AcademicRolloverView> {
  List<Map<String, dynamic>> years = [];
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> items = [];
  String? sourceYear, targetYear, batchId;
  bool loading = true, busy = false, completed = false;
  Map<String, String> decisions = {};
  Map<String, String?> targetClasses = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
    });
    try {
      years =
          (await db
                      .from('academic_years')
                      .select('id,name,active,is_closed')
                      .order('created_at', ascending: false)
                  as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      classes =
          (await db
                      .from('classes')
                      .select('id,name,section,academic_year_id')
                      .order('name')
                  as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      students =
          (await db
                      .from('students')
                      .select('id,name,class_name,phone')
                      .order('name')
                  as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final active = years
          .where((y) => y['active'] == true && y['is_closed'] != true)
          .toList();
      final targets = years
          .where((y) => y['active'] != true && y['is_closed'] != true)
          .toList();
      // Keep dropdown selections valid after a rollover closes the source year
      // and activates the target year; otherwise Flutter can assert on stale values.
      if (sourceYear == null ||
          !active.any((y) => y['id'].toString() == sourceYear)) {
        sourceYear = active.isNotEmpty ? active.first['id'].toString() : null;
      }
      if (targetYear == null ||
          !targets.any((y) => y['id'].toString() == targetYear)) {
        targetYear = targets.isNotEmpty ? targets.first['id'].toString() : null;
      }
    } catch (e) {
      _message(
        'تعذر تحميل بيانات الترحيل. تحقق من اتصال المدرسة وصلاحيات المدير.',
      );
    }
    if (mounted)
      setState(() {
        loading = false;
      });
  }

  String _studentName(String? id) {
    for (final s in students) {
      if (s['id']?.toString() == id) return s['name']?.toString() ?? 'طالب';
    }
    return 'طالب غير معروف';
  }

  Future<void> prepare() async {
    if (sourceYear == null || targetYear == null || sourceYear == targetYear) {
      _message('اختر السنة الحالية وسنة جديدة مختلفة.');
      return;
    }
    setState(() {
      busy = true;
    });
    try {
      final id = await db.rpc(
        'prepare_academic_rollover',
        params: {'p_source_year': sourceYear, 'p_target_year': targetYear},
      );
      batchId = id.toString();
      completed = false;
      await _loadItems();
    } catch (e) {
      _message('تعذر إعداد المعاينة: ${e.toString()}');
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  Future<void> _loadItems() async {
    if (batchId == null) return;
    final rows = await db
        .from('rollover_items')
        .select(
          'id,student_id,decision,target_class_id,source_balance,reviewed',
        )
        .eq('batch_id', batchId!)
        .order('created_at');
    items = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    decisions = {
      for (final i in items) i['id'].toString(): i['decision'].toString(),
    };
    targetClasses = {
      for (final i in items)
        i['id'].toString(): i['target_class_id']?.toString(),
    };
    if (mounted) setState(() {});
  }

  Future<void> saveItem(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final decision = decisions[id] ?? 'exclude';
    final classId = targetClasses[id];
    if ((decision == 'promote' || decision == 'repeat') && classId == null) {
      _message('حدد الصف الجديد للطالب قبل اعتماد قراره.');
      return;
    }
    setState(() {
      busy = true;
    });
    try {
      await db
          .from('rollover_items')
          .update({
            'decision': decision,
            'target_class_id': (decision == 'promote' || decision == 'repeat')
                ? classId
                : null,
            'reviewed': true,
            'reviewed_by': db.auth.currentUser?.id,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('batch_id', batchId!);
      await _loadItems();
      _message('تم حفظ قرار ${_studentName(item['student_id']?.toString())}.');
    } catch (e) {
      _message('تعذر حفظ القرار: ${e.toString()}');
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  Future<void> execute() async {
    if (items.isEmpty || items.any((i) => i['reviewed'] != true)) {
      _message('راجع قرار كل طالب أولًا؛ لا يمكن ترحيل بيانات غير مراجعة.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الترحيل النهائي'),
        content: const Text(
          'سيتم تفعيل السنة الجديدة وإقفال السنة السابقة وترحيل الأرصدة المستحقة. لا تبدأ قبل مراجعة جميع الطلاب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('مراجعة لاحقًا'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الترحيل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      busy = true;
    });
    try {
      final result = await db.rpc(
        'execute_academic_rollover',
        params: {'p_batch_id': batchId},
      );
      completed = true;
      _message(
        (result is Map ? result['message']?.toString() : null) ??
            'اكتمل الترحيل.',
      );
      await load();
      items = [];
    } catch (e) {
      _message('لم يكتمل الترحيل: ${e.toString()}');
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  void _message(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final targetClassesList = classes
        .where(
          (c) =>
              c['academic_year_id'] == targetYear ||
              c['academic_year_id'] == null,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ترحيل السنة الدراسية'),
        actions: [
          IconButton(
            onPressed: loading || busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'تتم مراجعة كل طالب بشكل مستقل. تبقى السجلات القديمة محفوظة، ويُنقل الدين المستحق للسنة الجديدة دون تكراره.',
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: sourceYear,
                  decoration: const InputDecoration(
                    labelText: 'السنة الحالية (المصدر)',
                  ),
                  items: years
                      .where(
                        (y) => y['active'] == true && y['is_closed'] != true,
                      )
                      .map(
                        (y) => DropdownMenuItem(
                          value: y['id'].toString(),
                          child: Text(y['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) => setState(() => sourceYear = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: targetYear,
                  decoration: const InputDecoration(
                    labelText: 'السنة الجديدة (الهدف)',
                  ),
                  items: years
                      .where(
                        (y) => y['active'] != true && y['is_closed'] != true,
                      )
                      .map(
                        (y) => DropdownMenuItem(
                          value: y['id'].toString(),
                          child: Text(y['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) => setState(() => targetYear = v),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : prepare,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('إعداد المعاينة ومراجعة الطلاب'),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: Text('عدد الطلاب: ${items.length}'),
                      subtitle: Text(
                        'تمت مراجعة ${items.where((i) => i['reviewed'] == true).length} من ${items.length}',
                      ),
                      leading: const Icon(Icons.people_alt_outlined),
                    ),
                  ),
                  ...items.map((item) {
                    final id = item['id'].toString();
                    final decision = decisions[id] ?? 'exclude';
                    final needsClass =
                        decision == 'promote' || decision == 'repeat';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studentName(item['student_id']?.toString()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الدين المرحّل: ${((item['source_balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} د.ل',
                            ),
                            DropdownButtonFormField<String>(
                              value: decision,
                              decoration: const InputDecoration(
                                labelText: 'النتيجة / القرار',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'promote',
                                  child: Text('ناجح'),
                                ),
                                DropdownMenuItem(
                                  value: 'repeat',
                                  child: Text('راسب'),
                                ),
                                DropdownMenuItem(
                                  value: 'graduate',
                                  child: Text('متخرج'),
                                ),
                                DropdownMenuItem(
                                  value: 'transfer',
                                  child: Text('منتقل'),
                                ),
                                DropdownMenuItem(
                                  value: 'exclude',
                                  child: Text('عدم الترحيل'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() {
                                      decisions[id] = v ?? 'exclude';
                                      item['reviewed'] = false;
                                    }),
                            ),
                            if (needsClass)
                              DropdownButtonFormField<String>(
                                value:
                                    targetClassesList.any(
                                      (c) =>
                                          c['id'].toString() ==
                                          targetClasses[id],
                                    )
                                    ? targetClasses[id]
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'الصف في السنة الجديدة',
                                ),
                                items: targetClassesList
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c['id'].toString(),
                                        child: Text(
                                          '${c['name']}${(c['section'] ?? '').toString().isEmpty ? '' : ' — ${c['section']}'}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() {
                                        targetClasses[id] = v;
                                        item['reviewed'] = false;
                                      }),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['reviewed'] == true
                                        ? 'تمت المراجعة'
                                        : 'بانتظار المراجعة',
                                    style: TextStyle(
                                      color: item['reviewed'] == true
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: busy ? null : () => saveItem(item),
                                  child: const Text('حفظ القرار'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: busy ? null : execute,
                    icon: const Icon(Icons.school),
                    label: const Text('تنفيذ الترحيل واعتماد السنة الجديدة'),
                  ),
                ],
                if (completed)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.check_circle),
                      title: Text('اكتمل ترحيل السنة بنجاح.'),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
