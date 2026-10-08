import 'package:flutter/material.dart';
import 'app_error.dart';
import 'package:flutter/services.dart';
import 'supabase_config.dart';

const _ownerGreen = Color(0xFF155D4A);

class OwnerConsole extends StatefulWidget {
  final String pin;
  const OwnerConsole({super.key, required this.pin});
  @override State<OwnerConsole> createState() => _OwnerConsoleState();
}

class _OwnerConsoleState extends State<OwnerConsole> {
  List<Map<String, dynamic>> schools = [];
  bool loading = true, creating = false;
  String? error, generatedCode, generatedSchool;

  @override
  void initState() { super.initState(); loadSchools(); }

  Future<Map<String, dynamic>> callOwner(String action, [Map<String, dynamic> extra = const {}]) async {
    final response = await db.functions.invoke('owner-api', body: {'action': action, 'pin': widget.pin, ...extra}).timeout(const Duration(seconds: 20));
    final data = response.data;
    if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
    if (data is! Map) throw Exception('استجابة غير صالحة من الخادم');
    return Map<String, dynamic>.from(data);
  }

  Future<void> loadSchools() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final data = await callOwner('list_schools');
      final raw = data['schools'];
      schools = raw is List ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
    } catch (e) {
      error = friendlyError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  void message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value), backgroundColor: error ? Colors.red.shade700 : null));
  }

  Future<void> createSchool() async {
    final name = TextEditingController(), code = TextEditingController();
    final username = TextEditingController(text: 'admin'), password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إنشاء مدرسة جديدة'),
      content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المدرسة'), validator: (v) => v == null || v.trim().length < 3 ? 'أدخل اسم المدرسة' : null),
        TextFormField(controller: code, decoration: const InputDecoration(labelText: 'رمز المدرسة'), validator: (v) => v == null || v.trim().length < 3 ? 'أدخل رمز المدرسة' : null),
        TextFormField(controller: username, decoration: const InputDecoration(labelText: 'اسم مدير المدرسة')),
        TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة مرور المدير'), validator: (v) => v == null || v.length < 6 ? '6 خانات على الأقل' : null),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: creating ? null : () async {
          if (!formKey.currentState!.validate()) return;
          setState(() => creating = true);
          try {
            await callOwner('create_school', {
              'name': name.text.trim(), 'code': code.text.trim(),
              'admin_username': username.text.trim(), 'admin_password': password.text, 'currency': 'د.ل',
            });
            if (ctx.mounted) Navigator.pop(ctx);
            await loadSchools();
            if (mounted) message('تم إنشاء المدرسة بنجاح');
          } catch (e) {
            if (mounted) message(friendlyError(e), error: true);
          } finally {
            if (mounted) setState(() => creating = false);
          }
        }, child: const Text('إنشاء')),
      ],
    ));
  }

  Future<void> generateLicense(Map<String, dynamic> school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رمز تفعيل دائم'),
        content: const Text(
          'سيتم إنشاء رمز واحد لهذه المدرسة. الرمز دائم ويُستخدم مرة واحدة فقط، وبعد نجاح التفعيل لا يمكن إنشاء رمز ثانٍ لنفس المدرسة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء الرمز')),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;
    try {
      final data = await callOwner('generate_license', {'school_id': school['id']});
      final code = data['code']?.toString();
      if (code == null || code.isEmpty) throw Exception('لم يُرجع الخادم رمز التفعيل');
      if (data['permanent'] != true || data['one_time'] != true) {
        throw Exception('استجابة الترخيص غير صالحة');
      }
      if (!mounted) return;
      setState(() {
        generatedCode = code;
        generatedSchool = school['name']?.toString() ?? school['code']?.toString();
      });
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) message('تم إنشاء الرمز الدائم لمرة واحدة ونسخه');
      await loadSchools();
    } catch (e) {
      if (mounted) message(friendlyError(e), error: true);
    }
  }

  Future<void> showSchoolDetails(Map<String, dynamic> school) async {
    try {
      final data = await callOwner('school_details', {'school_id': school['id']});
      final stats = data['stats'] is Map ? Map<String, dynamic>.from(data['stats'] as Map) : <String, dynamic>{};
      final users = data['users'] is List
          ? (data['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(school['name']?.toString() ?? 'تفاصيل المدرسة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("رمز المدرسة: ${school['code'] ?? '—'}"),
                Text("الحالة: ${school['licensed'] == true ? 'ترخيص دائم' : 'فترة تجريبية'}"),
                const Divider(),
                Text("الطلاب: ${stats['students'] ?? 0}"),
                Text("المعلمون: ${stats['teachers'] ?? 0}"),
                Text("حسابات المدرسة: ${users.length}"),
                const SizedBox(height: 8),
                ...users.map((u) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(u['active'] == true ? Icons.person : Icons.person_off),
                  title: Text("${u['username'] ?? '—'}"),
                  subtitle: Text("${u['role'] ?? '—'} • ${u['active'] == true ? 'نشط' : 'موقوف'}"),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) message(friendlyError(e), error: true);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مركز المالك', style: TextStyle(fontWeight: FontWeight.w800)),
      leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      actions: [IconButton(onPressed: loading ? null : loadSchools, icon: const Icon(Icons.refresh))],
    ),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: loadSchools,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Card(color: _ownerGreen, child: const ListTile(
          leading: CircleAvatar(child: Icon(Icons.admin_panel_settings)),
          title: Text('لوحة المالك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('إدارة المدارس والتراخيص الدائمة', style: TextStyle(color: Colors.white70)),
        )),
        if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('تعذر تحميل البيانات'), subtitle: Text(error!))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: _ownerStat('المدارس', schools.length.toString(), Icons.apartment)),
              const SizedBox(width: 8),
              Expanded(child: _ownerStat('مفعّلة', schools.where((s) => s['licensed'] == true).length.toString(), Icons.verified)),
              const SizedBox(width: 8),
              Expanded(child: _ownerStat('تجريبية', schools.where((s) => s['licensed'] != true).length.toString(), Icons.schedule)),
            ],
          ),
        ),
        Card(child: ListTile(
          leading: const Icon(Icons.add_business_outlined),
          title: const Text('إنشاء مدرسة جديدة'),
          subtitle: const Text('إنشاء المدرسة وحساب مديرها وبداية الفترة التجريبية'),
          trailing: const Icon(Icons.chevron_left),
          onTap: createSchool,
        )),
        if (generatedCode != null) Card(child: ListTile(
          leading: const Icon(Icons.vpn_key),
          title: const Text('رمز التفعيل الجديد'),
          subtitle: Text((generatedSchool ?? '') + '\n' + generatedCode! + '\nرمز دائم • استخدام مرة واحدة'),
          isThreeLine: true,
          trailing: IconButton(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: generatedCode!));
            if (mounted) message('تم نسخ الرمز');
          }, icon: const Icon(Icons.copy)),
        )),
        const SizedBox(height: 8),
        Text('المدارس (' + schools.length.toString() + ')', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (schools.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد مدارس بعد.')))
        else
          ...schools.map(schoolCard),
      ]),
    ),
  );

  Widget _ownerStat(String title, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Icon(icon, color: _ownerGreen),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );

  Widget schoolCard(Map<String, dynamic> school) {
    final licensed = school['licensed'] == true;
    final trial = school['trial_started_at'] != null;
    final status = licensed ? 'ترخيص دائم ومفعّل' : (trial ? 'فترة تجريبية' : 'غير مفعّلة');
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(child: Icon(licensed ? Icons.verified : Icons.school_outlined)),
          title: Text(school['name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text("الرمز: ${school['code'] ?? '—'}\n$status"),
          isThreeLine: true,
          onTap: () => showSchoolDetails(school),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                tooltip: 'تفاصيل المدرسة',
                onPressed: () => showSchoolDetails(school),
                icon: const Icon(Icons.info_outline),
              ),
              if (licensed)
                const Icon(Icons.check_circle, color: _ownerGreen)
              else
                IconButton(
                  tooltip: 'إنشاء رمز تفعيل دائم لمرة واحدة',
                  icon: const Icon(Icons.vpn_key_outlined),
                  onPressed: () => generateLicense(school),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
