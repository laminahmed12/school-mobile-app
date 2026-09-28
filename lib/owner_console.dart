import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ownerGreen = Color(0xFF155D4A);

class OwnerConsole extends StatefulWidget {
  final SharedPreferences prefs;
  const OwnerConsole({super.key, required this.prefs});

  @override
  State<OwnerConsole> createState() => _OwnerConsoleState();
}

class _OwnerConsoleState extends State<OwnerConsole> {
  String? lastCode;
  String lastPlan = 'لم يتم إنشاء ترخيص بعد';

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final parts = List.generate(4, (_) => List.generate(4, (_) => chars[r.nextInt(chars.length)]).join());
    return parts.join('-');
  }

  Future<void> _createLicense(String plan) async {
    final code = _generateCode();
    await widget.prefs.setString('owner_last_license_code', code);
    await widget.prefs.setString('owner_last_license_plan', plan);
    setState(() {
      lastCode = code;
      lastPlan = plan;
    });
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توليد الرمز ونسخه إلى الحافظة')));
  }

  @override
  void initState() {
    super.initState();
    lastCode = widget.prefs.getString('owner_last_license_code');
    lastPlan = widget.prefs.getString('owner_last_license_plan') ?? lastPlan;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المالك', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: _ownerGreen,
            child: const ListTile(
              leading: CircleAvatar(child: Icon(Icons.verified_user)),
              title: Text('لوحة المالك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('تحكم خاص بمالك تطبيق لامين', style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 8),
          _action(
            icon: Icons.vpn_key_outlined,
            title: 'توليد رمز تفعيل لعميل',
            subtitle: 'اختر مدة الترخيص ثم انسخ الرمز للعميل',
            onTap: () => _licenseDialog(context),
          ),
          _action(
            icon: Icons.key_outlined,
            title: 'آخر رمز تم توليده',
            subtitle: lastCode == null ? 'لا يوجد رمز محفوظ على هذا الجهاز' : '$lastPlan • $lastCode',
            onTap: lastCode == null ? null : () async {
              await Clipboard.setData(ClipboardData(text: lastCode!));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
            },
          ),
          _action(
            icon: Icons.security_outlined,
            title: 'أمان المالك',
            subtitle: 'رمز المالك لا يظهر داخل خانة الإدخال',
            onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(
              title: Text('أمان المالك'),
              content: Text('هذه الشاشة لا تستخدم البريد الإلكتروني. الدخول إليها يتم من شاشة الدخول عبر ثلاث نقرات على Adreemk ثم إدخال رمز المالك.'),
            )),
          ),
          _action(
            icon: Icons.school_outlined,
            title: 'العودة إلى التطبيق',
            subtitle: 'إغلاق لوحة المالك والعودة لشاشة الدخول',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _action({required IconData icon, required String title, required String subtitle, required VoidCallback? onTap}) => Card(
    child: ListTile(
      minVerticalPadding: 14,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle)),
      trailing: const Icon(Icons.chevron_left),
      onTap: onTap,
    ),
  );

  Future<void> _licenseDialog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerRight, child: Text('مدة الترخيص', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            const SizedBox(height: 10),
            _plan(ctx, '6 أشهر', 'ترخيص نصف سنوي'),
            _plan(ctx, 'سنة', 'ترخيص سنوي'),
            _plan(ctx, 'دائم', 'ترخيص دائم'),
          ]),
        ),
      ),
    );
  }

  Widget _plan(BuildContext ctx, String title, String subtitle) => Card(
    child: ListTile(
      leading: const Icon(Icons.verified_outlined),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_left),
      onTap: () async {
        Navigator.pop(ctx);
        await _createLicense(title);
      },
    ),
  );
}
