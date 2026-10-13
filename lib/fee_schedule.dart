import 'package:flutter/material.dart';
import 'supabase_config.dart';

class FeeScheduleView extends StatefulWidget {
  final String role;
  const FeeScheduleView({super.key, required this.role});
  @override
  State<FeeScheduleView> createState() => _FeeScheduleViewState();
}

class _FeeScheduleViewState extends State<FeeScheduleView> {
  List<Map<String, dynamic>> years = [];
  List<Map<String, dynamic>> schedules = [];
  List<Map<String, dynamic>> classes = [];
  String? yearId;
  bool loading = true;
  bool saving = false;
  String? error;

  bool get canDelete => widget.role == 'admin' || widget.role == 'owner';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      years = (await db.from('academic_years').select('id,name,active,is_closed').order('starts_on', ascending: false) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();
      if (yearId == null || !years.any((e) => e['id'].toString() == yearId)) {
        final active = years.where((e) => e['active'] == true).toList();
        yearId = (active.isNotEmpty ? active.first : (years.isNotEmpty ? years.first : null))?['id']?.toString();
      }
      classes = (await db.from('classes').select('id,name,grade_order,academic_year_id').order('grade_order') as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();
      await loadSchedules();
    } catch (e) { error = 'تعذر تحميل جداول الرسوم: ' + e.toString(); }
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadSchedules() async {
    if (yearId == null) { schedules = []; return; }
    schedules = (await db.from('fee_schedules').select('id,academic_year_id,grade_order,term,amount,due_date,active,note')
        .eq('academic_year_id', yearId!).order('grade_order').order('term') as List)
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> edit({Map<String, dynamic>? item}) async {
    if (yearId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنشئ سنة دراسية أولاً.'))); return; }
    final gradeSet = <int>{};
    for (final c in classes) {
      final y = c['academic_year_id']?.toString();
      final n = (c['grade_order'] as num?)?.toInt();
      if (n != null && (y == null || y == yearId)) gradeSet.add(n);
    }
    if (item != null) gradeSet.add((item['grade_order'] as num).toInt());
    if (gradeSet.isEmpty) gradeSet.addAll(List<int>.generate(12, (i) => i + 1));
    final grades = gradeSet.toList()..sort();
    int grade = (item?['grade_order'] as num?)?.toInt() ?? grades.first;
    String term = item?['term']?.toString() ?? 'الفصل الأول';
    bool active = item?['active'] != false;
    final amount = TextEditingController(text: item?['amount']?.toString() ?? '');
    final due = TextEditingController(text: item?['due_date']?.toString() ?? '');
    final note = TextEditingController(text: item?['note']?.toString() ?? '');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(item == null ? 'إضافة رسوم قياسية' : 'تعديل الرسوم القياسية'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(value: grade, decoration: const InputDecoration(labelText: 'الصف الدراسي'),
          items: grades.map((g) => DropdownMenuItem(value: g, child: Text('الصف ' + g.toString()))).toList(),
          onChanged: (v) { if (v != null) setDialog(() => grade = v); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: term, decoration: const InputDecoration(labelText: 'الفصل الدراسي'),
          items: const [DropdownMenuItem(value: 'الفصل الأول', child: Text('الفصل الأول')), DropdownMenuItem(value: 'الفصل الثاني', child: Text('الفصل الثاني')), DropdownMenuItem(value: 'الفصل الثالث', child: Text('الفصل الثالث'))],
          onChanged: (v) { if (v != null) setDialog(() => term = v); }),
        const SizedBox(height: 10),
        TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الرسوم القياسية (د.ل)'),
          validator: (v) { final n = double.tryParse((v ?? '').trim().replaceAll(',', '.')); return n == null || n < 0 ? 'أدخل مبلغًا صحيحًا' : null; }),
        const SizedBox(height: 10),
        TextFormField(controller: due, decoration: const InputDecoration(labelText: 'تاريخ الاستحقاق (اختياري YYYY-MM-DD)'),
          validator: (v) { final s = (v ?? '').trim(); if (s.isEmpty) return null; return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ? null : 'استخدم الصيغة YYYY-MM-DD'; }),
        const SizedBox(height: 10),
        TextFormField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
        SwitchListTile(value: active, contentPadding: EdgeInsets.zero, title: const Text('الجدول فعال'), onChanged: (v) => setDialog(() => active = v)),
        const Text('تعديل الجدول لا يغيّر تلقائيًا الاستحقاقات المسجلة سابقًا.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: saving ? null : () async {
          if (!form.currentState!.validate()) return;
          setDialog(() => saving = true);
          try {
            final user = db.auth.currentUser;
            final profile = user == null ? null : await db.from('profiles').select('school_id').eq('user_id', user.id).maybeSingle();
            final schoolId = profile?['school_id']?.toString();
            if (schoolId == null || schoolId.isEmpty) throw Exception('تعذر تحديد المدرسة الحالية.');
            final data = <String, dynamic>{'school_id': schoolId, 'academic_year_id': yearId, 'grade_order': grade, 'term': term,
              'amount': double.parse(amount.text.trim().replaceAll(',', '.')), 'due_date': due.text.trim().isEmpty ? null : due.text.trim(),
              'active': active, 'note': note.text.trim(), 'updated_by': user?.id};
            if (item == null) { data['created_by'] = user?.id; await db.from('fee_schedules').insert(data); }
            else { await db.from('fee_schedules').update(data).eq('id', item['id']); }
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذر حفظ الرسوم: ' + e.toString())));
          } finally { if (ctx.mounted) setDialog(() => saving = false); }
        }, child: Text(saving ? 'جار الحفظ...' : 'حفظ')),
      ],
    ))) ?? false;
    amount.dispose(); due.dispose(); note.dispose();
    if (ok == true) { await loadSchedules(); if (mounted) setState(() {}); }
  }

  Future<void> delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف تعريف الرسوم'),
      content: const Text('سيُحذف تعريف الرسوم القياسية فقط، ولن تتغير الاستحقاقات التاريخية للطلاب. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
    )) ?? false;
    if (!yes) return;
    try { await db.from('fee_schedules').delete().eq('id', item['id']); await loadSchedules(); if (mounted) setState(() {}); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: ' + e.toString()))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الرسوم القياسية'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: loading ? null : () => edit(), icon: const Icon(Icons.add), label: const Text('إضافة رسوم')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: const Color(0xFF155D4A), child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رسوم واضحة لكل صف وفصل', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('تُحفظ الرسوم بحسب السنة والصف والفصل. تغيير الجدول لا يغيّر رسوم السنوات السابقة.', style: TextStyle(color: Colors.white)),
      ]))),
      if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(error!))),
      if (years.isEmpty) const Card(child: ListTile(title: Text('لا توجد سنة دراسية'), subtitle: Text('أضف سنة دراسية أولاً ثم أنشئ جدول الرسوم.'))),
      if (years.isNotEmpty) DropdownButtonFormField<String>(value: yearId, decoration: const InputDecoration(labelText: 'السنة الدراسية'),
        items: years.map((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['name']?.toString() ?? 'سنة بلا اسم'))).toList(),
        onChanged: (v) async { setState(() { yearId = v; loading = true; }); try { await loadSchedules(); } catch (e) { error = e.toString(); } if (mounted) setState(() => loading = false); }),
      const SizedBox(height: 10),
      if (schedules.isEmpty && years.isNotEmpty) const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('لا توجد رسوم قياسية لهذه السنة بعد'), subtitle: Text('أضف رسومًا لكل صف وفصل دراسي.'))),
      ...schedules.map((s) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE1F4ED), child: Text(s['grade_order'].toString())),
        title: Text('الصف ' + s['grade_order'].toString() + ' - ' + s['term'].toString()),
        subtitle: Text((s['amount'] as num).toStringAsFixed(2) + ' د.ل' + (s['due_date'] == null ? '' : ' • استحقاق ' + s['due_date'].toString()) + (s['active'] == true ? '' : ' • غير فعال')),
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') edit(item: s); if (v == 'delete') delete(s); }, itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('تعديل')), if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ]),
      ))),
      const SizedBox(height: 80),
    ])),
  );
}
).hasMatch(s) ? null : 'استخدم الصيغة YYYY-MM-DD'; }),
        const SizedBox(height: 10),
        TextFormField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
        SwitchListTile(value: active, contentPadding: EdgeInsets.zero, title: const Text('الجدول فعال'), onChanged: (v) => setDialog(() => active = v)),
        const Text('تعديل الجدول لا يغيّر تلقائيًا الاستحقاقات المسجلة سابقًا.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: saving ? null : () async {
          if (!form.currentState!.validate()) return;
          setDialog(() => saving = true);
          try {
            final user = db.auth.currentUser;
            final profile = user == null ? null : await db.from('profiles').select('school_id').eq('user_id', user.id).maybeSingle();
            final schoolId = profile?['school_id']?.toString();
            if (schoolId == null || schoolId.isEmpty) throw Exception('تعذر تحديد المدرسة الحالية.');
            final data = <String, dynamic>{'school_id': schoolId, 'academic_year_id': yearId, 'grade_order': grade, 'term': term,
              'amount': double.parse(amount.text.trim().replaceAll(',', '.')), 'due_date': due.text.trim().isEmpty ? null : due.text.trim(),
              'active': active, 'note': note.text.trim(), 'updated_by': user?.id};
            if (item == null) { data['created_by'] = user?.id; await db.from('fee_schedules').insert(data); }
            else { await db.from('fee_schedules').update(data).eq('id', item['id']); }
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذر حفظ الرسوم: ' + e.toString())));
          } finally { if (ctx.mounted) setDialog(() => saving = false); }
        }, child: Text(saving ? 'جار الحفظ...' : 'حفظ')),
      ],
    ))) ?? false;
    amount.dispose(); due.dispose(); note.dispose();
    if (ok == true) { await loadSchedules(); if (mounted) setState(() {}); }
  }

  Future<void> delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف تعريف الرسوم'),
      content: const Text('سيُحذف تعريف الرسوم القياسية فقط، ولن تتغير الاستحقاقات التاريخية للطلاب. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
    )) ?? false;
    if (!yes) return;
    try { await db.from('fee_schedules').delete().eq('id', item['id']); await loadSchedules(); if (mounted) setState(() {}); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: ' + e.toString()))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الرسوم القياسية'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: loading ? null : () => edit(), icon: const Icon(Icons.add), label: const Text('إضافة رسوم')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: const Color(0xFF155D4A), child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رسوم واضحة لكل صف وفصل', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('تُحفظ الرسوم بحسب السنة والصف والفصل. تغيير الجدول لا يغيّر رسوم السنوات السابقة.', style: TextStyle(color: Colors.white)),
      ]))),
      if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(error!))),
      if (years.isEmpty) const Card(child: ListTile(title: Text('لا توجد سنة دراسية'), subtitle: Text('أضف سنة دراسية أولاً ثم أنشئ جدول الرسوم.'))),
      if (years.isNotEmpty) DropdownButtonFormField<String>(value: yearId, decoration: const InputDecoration(labelText: 'السنة الدراسية'),
        items: years.map((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['name']?.toString() ?? 'سنة بلا اسم'))).toList(),
        onChanged: (v) async { setState(() { yearId = v; loading = true; }); try { await loadSchedules(); } catch (e) { error = e.toString(); } if (mounted) setState(() => loading = false); }),
      const SizedBox(height: 10),
      if (schedules.isEmpty && years.isNotEmpty) const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('لا توجد رسوم قياسية لهذه السنة بعد'), subtitle: Text('أضف رسومًا لكل صف وفصل دراسي.'))),
      ...schedules.map((s) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE1F4ED), child: Text(s['grade_order'].toString())),
        title: Text('الصف ' + s['grade_order'].toString() + ' - ' + s['term'].toString()),
        subtitle: Text((s['amount'] as num).toStringAsFixed(2) + ' د.ل' + (s['due_date'] == null ? '' : ' • استحقاق ' + s['due_date'].toString()) + (s['active'] == true ? '' : ' • غير فعال')),
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') edit(item: s); if (v == 'delete') delete(s); }, itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('تعديل')), if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ]),
      ))),
      const SizedBox(height: 80),
    ])),
  );
}
).hasMatch(s) ? null : 'استخدم الصيغة YYYY-MM-DD'; }),
        const SizedBox(height: 10),
        TextFormField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
        SwitchListTile(value: active, contentPadding: EdgeInsets.zero, title: const Text('الجدول فعال'), onChanged: (v) => setDialog(() => active = v)),
        const Text('تعديل الجدول لا يغيّر تلقائيًا الاستحقاقات المسجلة سابقًا.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: saving ? null : () async {
          if (!form.currentState!.validate()) return;
          setDialog(() => saving = true);
          try {
            final user = db.auth.currentUser;
            final profile = user == null ? null : await db.from('profiles').select('school_id').eq('user_id', user.id).maybeSingle();
            final schoolId = profile?['school_id']?.toString();
            if (schoolId == null || schoolId.isEmpty) throw Exception('تعذر تحديد المدرسة الحالية.');
            final data = <String, dynamic>{'school_id': schoolId, 'academic_year_id': yearId, 'grade_order': grade, 'term': term,
              'amount': double.parse(amount.text.trim().replaceAll(',', '.')), 'due_date': due.text.trim().isEmpty ? null : due.text.trim(),
              'active': active, 'note': note.text.trim(), 'updated_by': user?.id};
            if (item == null) { data['created_by'] = user?.id; await db.from('fee_schedules').insert(data); }
            else { await db.from('fee_schedules').update(data).eq('id', item['id']); }
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذر حفظ الرسوم: ' + e.toString())));
          } finally { if (ctx.mounted) setDialog(() => saving = false); }
        }, child: Text(saving ? 'جار الحفظ...' : 'حفظ')),
      ],
    ))) ?? false;
    amount.dispose(); due.dispose(); note.dispose();
    if (ok == true) { await loadSchedules(); if (mounted) setState(() {}); }
  }

  Future<void> delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف تعريف الرسوم'),
      content: const Text('سيُحذف تعريف الرسوم القياسية فقط، ولن تتغير الاستحقاقات التاريخية للطلاب. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
    )) ?? false;
    if (!yes) return;
    try { await db.from('fee_schedules').delete().eq('id', item['id']); await loadSchedules(); if (mounted) setState(() {}); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: ' + e.toString()))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الرسوم القياسية'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: loading ? null : () => edit(), icon: const Icon(Icons.add), label: const Text('إضافة رسوم')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: const Color(0xFF155D4A), child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رسوم واضحة لكل صف وفصل', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('تُحفظ الرسوم بحسب السنة والصف والفصل. تغيير الجدول لا يغيّر رسوم السنوات السابقة.', style: TextStyle(color: Colors.white)),
      ]))),
      if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(error!))),
      if (years.isEmpty) const Card(child: ListTile(title: Text('لا توجد سنة دراسية'), subtitle: Text('أضف سنة دراسية أولاً ثم أنشئ جدول الرسوم.'))),
      if (years.isNotEmpty) DropdownButtonFormField<String>(value: yearId, decoration: const InputDecoration(labelText: 'السنة الدراسية'),
        items: years.map((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['name']?.toString() ?? 'سنة بلا اسم'))).toList(),
        onChanged: (v) async { setState(() { yearId = v; loading = true; }); try { await loadSchedules(); } catch (e) { error = e.toString(); } if (mounted) setState(() => loading = false); }),
      const SizedBox(height: 10),
      if (schedules.isEmpty && years.isNotEmpty) const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('لا توجد رسوم قياسية لهذه السنة بعد'), subtitle: Text('أضف رسومًا لكل صف وفصل دراسي.'))),
      ...schedules.map((s) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE1F4ED), child: Text(s['grade_order'].toString())),
        title: Text('الصف ' + s['grade_order'].toString() + ' - ' + s['term'].toString()),
        subtitle: Text((s['amount'] as num).toStringAsFixed(2) + ' د.ل' + (s['due_date'] == null ? '' : ' • استحقاق ' + s['due_date'].toString()) + (s['active'] == true ? '' : ' • غير فعال')),
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') edit(item: s); if (v == 'delete') delete(s); }, itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('تعديل')), if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ]),
      ))),
      const SizedBox(height: 80),
    ])),
  );
}
        const SizedBox(height: 10),
        TextFormField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
        SwitchListTile(value: active, contentPadding: EdgeInsets.zero, title: const Text('الجدول فعال'), onChanged: (v) => setDialog(() => active = v)),
        const Text('تعديل الجدول لا يغيّر تلقائيًا الاستحقاقات المسجلة سابقًا.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: saving ? null : () async {
          if (!form.currentState!.validate()) return;
          setDialog(() => saving = true);
          try {
            final user = db.auth.currentUser;
            final profile = user == null ? null : await db.from('profiles').select('school_id').eq('user_id', user.id).maybeSingle();
            final schoolId = profile?['school_id']?.toString();
            if (schoolId == null || schoolId.isEmpty) throw Exception('تعذر تحديد المدرسة الحالية.');
            final data = <String, dynamic>{'school_id': schoolId, 'academic_year_id': yearId, 'grade_order': grade, 'term': term,
              'amount': double.parse(amount.text.trim().replaceAll(',', '.')), 'due_date': due.text.trim().isEmpty ? null : due.text.trim(),
              'active': active, 'note': note.text.trim(), 'updated_by': user?.id};
            if (item == null) { data['created_by'] = user?.id; await db.from('fee_schedules').insert(data); }
            else { await db.from('fee_schedules').update(data).eq('id', item['id']); }
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذر حفظ الرسوم: ' + e.toString())));
          } finally { if (ctx.mounted) setDialog(() => saving = false); }
        }, child: Text(saving ? 'جار الحفظ...' : 'حفظ')),
      ],
    ))) ?? false;
    amount.dispose(); due.dispose(); note.dispose();
    if (ok == true) { await loadSchedules(); if (mounted) setState(() {}); }
  }

  Future<void> delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف تعريف الرسوم'),
      content: const Text('سيُحذف تعريف الرسوم القياسية فقط، ولن تتغير الاستحقاقات التاريخية للطلاب. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
    )) ?? false;
    if (!yes) return;
    try { await db.from('fee_schedules').delete().eq('id', item['id']); await loadSchedules(); if (mounted) setState(() {}); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: ' + e.toString()))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الرسوم القياسية'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: loading ? null : () => edit(), icon: const Icon(Icons.add), label: const Text('إضافة رسوم')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: const Color(0xFF155D4A), child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رسوم واضحة لكل صف وفصل', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('تُحفظ الرسوم بحسب السنة والصف والفصل. تغيير الجدول لا يغيّر رسوم السنوات السابقة.', style: TextStyle(color: Colors.white)),
      ]))),
      if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(error!))),
      if (years.isEmpty) const Card(child: ListTile(title: Text('لا توجد سنة دراسية'), subtitle: Text('أضف سنة دراسية أولاً ثم أنشئ جدول الرسوم.'))),
      if (years.isNotEmpty) DropdownButtonFormField<String>(value: yearId, decoration: const InputDecoration(labelText: 'السنة الدراسية'),
        items: years.map((y) => DropdownMenuItem(value: y['id'].toString(), child: Text(y['name']?.toString() ?? 'سنة بلا اسم'))).toList(),
        onChanged: (v) async { setState(() { yearId = v; loading = true; }); try { await loadSchedules(); } catch (e) { error = e.toString(); } if (mounted) setState(() => loading = false); }),
      const SizedBox(height: 10),
      if (schedules.isEmpty && years.isNotEmpty) const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('لا توجد رسوم قياسية لهذه السنة بعد'), subtitle: Text('أضف رسومًا لكل صف وفصل دراسي.'))),
      ...schedules.map((s) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE1F4ED), child: Text(s['grade_order'].toString())),
        title: Text('الصف ' + s['grade_order'].toString() + ' - ' + s['term'].toString()),
        subtitle: Text((s['amount'] as num).toStringAsFixed(2) + ' د.ل' + (s['due_date'] == null ? '' : ' • استحقاق ' + s['due_date'].toString()) + (s['active'] == true ? '' : ' • غير فعال')),
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') edit(item: s); if (v == 'delete') delete(s); }, itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('تعديل')), if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ]),
      ))),
      const SizedBox(height: 80),
    ])),
  );
}
