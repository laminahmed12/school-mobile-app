import 'package:flutter/material.dart';
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
    final response = await db.functions.invoke('owner-api', body: {'action': action, 'pin': widget.pin, ...extra});
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
      error = e.toString().replaceFirst('Exception: ', '');
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
            if (mounted) message(e.toString().replaceFirst('Exception: ', ''), error: true);
          } finally {
            if (mounted) setState(() => creating = false);
          }
        }, child: const Text('إنشاء')),
      ],
    ));
  }

  Future<void> generateLicense(Map<String, dynamic> school) async {
    try {
      final data = await callOwner('generate_license', {'school_id': school['id']});
      final code = data['code']?.toString();
      if (code == null || code.isEmpty) throw Exception('لم يُرجع الخادم رمز التفعيل');
      setState(() {
        generatedCode = code;
        generatedSchool = school['name']?.toString() ?? school['code']?.toString();
      });
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) message('تم إنشاء رمز التفعيل الدائم ونسخه');
      await loadSchools();
    } catch (e) {
      if (mounted) message(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('إدارة المالك', style: TextStyle(fontWeight: FontWeight.w800)),
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
        Card(child: ListTile(
          leading: const Icon(Icons.add_business_outlined),
          title: const Text('إنشاء مدرسة'),
          subtitle: const Text('إنشاء المدرسة وحساب مديرها'),
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

  Widget schoolCard(Map<String, dynamic> school) {
    final licensed = school['licensed'] == true;
    final trial = school['trial_started_at'] != null;
    final status = licensed ? 'الترخيص: دائم ومفعّل' : (trial ? 'الحالة: فترة تجريبية' : 'الحالة: غير مفعّلة');
    return Card(child: ListTile(
      leading: CircleAvatar(child: Icon(licensed ? Icons.verified : Icons.school_outlined)),
      title: Text(school['name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('الرمز: ' + (school['code']?.toString() ?? '—') + '\n' + status),
      isThreeLine: true,
      trailing: licensed
        ? const Icon(Icons.check_circle, color: _ownerGreen)
        : IconButton(tooltip: 'توليد رمز دائم', icon: const Icon(Icons.vpn_key_outlined), onPressed: () => generateLicense(school)),
    ));
  }
}
