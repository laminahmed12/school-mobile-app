import 'package:flutter/material.dart';
import 'supabase_config.dart';

class DiscountManagementView extends StatefulWidget {
  final String role;
  const DiscountManagementView({super.key, required this.role});
  @override
  State<DiscountManagementView> createState() => _DiscountManagementViewState();
}

class _DiscountManagementViewState extends State<DiscountManagementView> {
  List<Map<String, dynamic>> rules = [];
  List<Map<String, dynamic>> awards = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> assessments = [];
  String? error;
  bool loading = true;
  bool saving = false;
  bool get isAdmin => widget.role == 'admin' || widget.role == 'owner';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      rules = (await db.from('discount_rules').select().order('created_at', ascending: false) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      awards = (await db.from('student_discount_awards').select().order('created_at', ascending: false) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      students = (await db.from('students').select('id,name').order('name') as List).map((e) => Map<String, dynamic>.from(e)).toList();
      assessments = (await db.from('student_fee_assessments').select('id,student_id,academic_year_label,term,total_fee,discount,manual_discount').order('created_at', ascending: false) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) { error = 'تعذر تحميل الخصومات: ' + e.toString(); }
    if (mounted) setState(() => loading = false);
  }

  String studentName(String? id) {
    for (final s in students) { if (s['id']?.toString() == id) return s['name']?.toString() ?? 'طالب'; }
    return 'طالب';
  }

  Future<void> createRule() async {
    if (!isAdmin) return;
    final name = TextEditingController();
    final value = TextEditingController();
    final max = TextEditingController();
    final cap = TextEditingController();
    String ruleType = 'manual', valueType = 'fixed', stacking = 'max_only';
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('قاعدة خصم جديدة'),
      content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم القاعدة'), validator: (v) => (v ?? '').trim().isEmpty ? 'أدخل اسم القاعدة' : null),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: ruleType, decoration: const InputDecoration(labelText: 'نوع الخصم'),
          items: const [DropdownMenuItem(value: 'sibling', child: Text('الأخوة')), DropdownMenuItem(value: 'category', child: Text('فئة محددة')), DropdownMenuItem(value: 'scholarship', child: Text('منحة')), DropdownMenuItem(value: 'manual', child: Text('يدوي')), DropdownMenuItem(value: 'other', child: Text('أخرى'))],
          onChanged: (v) { if (v != null) setDialog(() => ruleType = v); }),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: valueType, decoration: const InputDecoration(labelText: 'طريقة الحساب'),
          items: const [DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت بالدينار')), DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية'))],
          onChanged: (v) { if (v != null) setDialog(() => valueType = v); }),
        const SizedBox(height: 8),
        TextFormField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'قيمة الخصم'),
          validator: (v) { final n = double.tryParse((v ?? '').replaceAll(',', '.')); return n == null || n < 0 || (valueType == 'percent' && n > 100) ? 'قيمة غير صحيحة' : null; }),
        const SizedBox(height: 8),
        TextFormField(controller: max, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الحد الأقصى للخصم (اختياري)')),
        const SizedBox(height: 8),
        TextFormField(controller: cap, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سقف القاعدة لكل استحقاق (اختياري)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: stacking, decoration: const InputDecoration(labelText: 'دمج الخصومات'),
          items: const [DropdownMenuItem(value: 'max_only', child: Text('خصم واحد لكل استحقاق')), DropdownMenuItem(value: 'stack', child: Text('السماح بالجمع ضمن سقف الرسوم'))],
          onChanged: (v) { if (v != null) setDialog(() => stacking = v); }),
      ]))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: saving ? null : () async {
          if (!key.currentState!.validate()) return;
          setDialog(() => saving = true);
          try {
            final user = db.auth.currentUser;
            final p = user == null ? null : await db.from('profiles').select('school_id').eq('user_id', user.id).maybeSingle();
            final schoolId = p?['school_id']?.toString();
            if (schoolId == null || schoolId.isEmpty) throw Exception('تعذر تحديد المدرسة.');
            final maxValue = max.text.trim().isEmpty ? null : double.tryParse(max.text.trim().replaceAll(',', '.'));
            final capValue = cap.text.trim().isEmpty ? null : double.tryParse(cap.text.trim().replaceAll(',', '.'));
            if (max.text.trim().isNotEmpty && (maxValue == null || maxValue < 0)) throw Exception('الحد الأقصى غير صحيح.');
            if (cap.text.trim().isNotEmpty && (capValue == null || capValue < 0)) throw Exception('سقف القاعدة غير صحيح.');
            await db.from('discount_rules').insert({
              'school_id': schoolId, 'name': name.text.trim(), 'rule_type': ruleType,
              'value_type': valueType, 'value': double.parse(value.text.trim().replaceAll(',', '.')),
              'max_amount': maxValue, 'cap_amount': capValue, 'stacking_policy': stacking,
              'created_by': user?.id, 'updated_by': user?.id,
            });
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذر حفظ القاعدة: ' + e.toString())));
          } finally { if (ctx.mounted) setDialog(() => saving = false); }
        }, child: Text(saving ? 'جار الحفظ...' : 'حفظ القاعدة')),
      ],
    ))) ?? false;
    name.dispose(); value.dispose(); max.dispose(); cap.dispose();
    if (ok == true) await load();
  }

  Future<void> requestAward() async {
    if (students.isEmpty || assessments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل طالب واستحقاق رسوم أولاً.')));
      return;
    }
    String studentId = students.first['id'].toString();
    String? assessmentId = assessments.firstWhere((a) => a['student_id'].toString() == studentId, orElse: () => assessments.first)['id']?.toString();
    String? ruleId;
    final amount = TextEditingController();
    final reason = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
      final studentAssessments = assessments.where((a) => a['student_id'].toString() == studentId).toList();
      if (studentAssessments.isNotEmpty && !studentAssessments.any((a) => a['id'].toString() == assessmentId)) assessmentId = studentAssessments.first['id'].toString();
      return AlertDialog(
        title: const Text('طلب خصم لطالب'),
        content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: studentId, decoration: const InputDecoration(labelText: 'الطالب'),
            items: students.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'].toString()))).toList(),
            onChanged: (v) { if (v != null) setDialog(() { studentId = v; final a = assessments.where((x) => x['student_id'].toString() == v).toList(); assessmentId = a.isEmpty ? null : a.first['id'].toString(); }); }),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: assessmentId, decoration: const InputDecoration(labelText: 'استحقاق الرسوم'),
            items: studentAssessments.map((a) => DropdownMenuItem(value: a['id'].toString(), child: Text(a['academic_year_label'].toString() + ' • ' + a['term'].toString() + ' • ' + (a['total_fee'] as num).toStringAsFixed(2) + ' د.ل'))).toList(),
            onChanged: (v) => setDialog(() => assessmentId = v)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: ruleId, decoration: const InputDecoration(labelText: 'قاعدة الخصم (اختياري)'),
            items: [const DropdownMenuItem<String>(value: null, child: Text('خصم يدوي')),...rules.where((r) => r['active'] == true).map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['name'].toString())))],
            onChanged: (v) => setDialog(() => ruleId = v)),
          const SizedBox(height: 8),
          TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'قيمة الخصم بالدينار'),
            validator: (v) { final n = double.tryParse((v ?? '').replaceAll(',', '.')); return n == null || n <= 0 ? 'أدخل مبلغًا صحيحًا' : null; }),
          const SizedBox(height: 8),
          TextFormField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'السبب'), validator: (v) => (v ?? '').trim().isEmpty ? 'سبب الخصم مطلوب' : null),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: saving ? null : () async {
            if (!key.currentState!.validate() || assessmentId == null) return;
            setDialog(() => saving = true);
            try {
              final user = db.auth.currentUser;
              final p = user == null ? null : await db.from('profiles').select('school_id').eq('user_id', user.id).maybeSingle();
              final schoolId = p?['school_id']?.toString();
              if (schoolId == null || schoolId.isEmpty) throw Exception('تعذر تحديد المدرسة.');
              final rule = rules.where((r) => r['id']?.toString() == ruleId).toList();
              await db.from('student_discount_awards').insert({
                'school_id': schoolId, 'student_id': studentId, 'fee_assessment_id': assessmentId,
                'discount_rule_id': ruleId, 'rule_snapshot': rule.isEmpty ? {'rule_type':'manual'} : rule.first,
                'amount': double.parse(amount.text.trim().replaceAll(',', '.')), 'reason': reason.text.trim(),
                'status': 'pending', 'requested_by': user?.id, 'created_by': user?.id,
              });
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذر إرسال طلب الخصم: ' + e.toString())));
            } finally { if (ctx.mounted) setDialog(() => saving = false); }
          }, child: Text(saving ? 'جار الإرسال...' : 'إرسال للاعتماد')),
        ],
      );
    })) ?? false;
    amount.dispose(); reason.dispose();
    if (ok == true) await load();
  }

  Future<void> changeStatus(Map<String, dynamic> award, String status) async {
    if (!isAdmin) return;
    try {
      await db.from('student_discount_awards').update({'status': status, 'updated_by': db.auth.currentUser?.id}).eq('id', award['id']);
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الخصم: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الخصومات والاعتمادات'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: loading ? null : requestAward, icon: const Icon(Icons.add), label: const Text('طلب خصم')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: const Color(0xFF155D4A), child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('خصومات موثقة ومراجعة واضحة', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('كل طلب يحفظ السبب والقيمة وصاحب الطلب، ويحتاج اعتماد المدير قبل احتسابه.', style: TextStyle(color: Colors.white)),
      ]))),
      if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(error!))),
      if (isAdmin) Card(child: ListTile(leading: const Icon(Icons.rule_folder_outlined), title: const Text('قواعد الخصم'), subtitle: Text(rules.length.toString() + ' قاعدة'), trailing: const Icon(Icons.add), onTap: createRule)),
      ...rules.map((r) => Card(child: ListTile(leading: const Icon(Icons.rule), title: Text(r['name'].toString()), subtitle: Text(r['rule_type'].toString() + ' • ' + r['value'].toString() + (r['value_type'] == 'percent' ? '%' : ' د.ل') + ' • ' + (r['stacking_policy'] == 'stack' ? 'قابل للجمع' : 'خصم واحد')))),
      if (awards.isEmpty) const Card(child: ListTile(title: Text('لا توجد طلبات خصم بعد'))),
      ...awards.map((a) {
        final status = a['status']?.toString() ?? 'pending';
        final statusLabel = status == 'approved' ? 'معتمد' : status == 'rejected' ? 'مرفوض' : status == 'reversed' ? 'معكوس' : 'بانتظار الاعتماد';
        return Card(child: ListTile(
          leading: CircleAvatar(child: Icon(status == 'approved' ? Icons.verified : status == 'pending' ? Icons.hourglass_top : Icons.receipt_long)),
          title: Text(studentName(a['student_id']?.toString()) + ' • ' + (a['amount'] as num).toStringAsFixed(2) + ' د.ل'),
          subtitle: Text(statusLabel + ' • ' + a['reason'].toString()),
          isThreeLine: true,
          trailing: isAdmin && status == 'pending' ? PopupMenuButton<String>(onSelected: (v) { if (v == 'approve') changeStatus(a, 'approved'); if (v == 'reject') changeStatus(a, 'rejected'); }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'approve', child: Text('اعتماد الخصم')), PopupMenuItem(value: 'reject', child: Text('رفض الطلب')),
          ]) : (isAdmin && status == 'approved' ? IconButton(tooltip: 'عكس الخصم', onPressed: () => changeStatus(a, 'reversed'), icon: const Icon(Icons.undo)) : null),
        ));
      }),
      const SizedBox(height: 80),
    ])),
  );
}
