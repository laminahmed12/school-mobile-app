import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'repository.dart';
import 'whatsapp.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(LaminApp(prefs: prefs));
}

class LaminApp extends StatelessWidget {
  final SharedPreferences prefs;
  const LaminApp({super.key, required this.prefs});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'لامين',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155D4A)),
      scaffoldBackgroundColor: const Color(0xFFF6F7F4),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
    ),
    home: AuthGate(prefs: prefs),
  );
}

class AuthGate extends StatelessWidget {
  final SharedPreferences prefs;
  const AuthGate({super.key, required this.prefs});
  @override Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: db.auth.onAuthStateChange,
    builder: (_, __) => db.auth.currentSession == null ? LoginPage(prefs: prefs) : HomePage(prefs: prefs),
  );
}

class LoginPage extends StatefulWidget {
  final SharedPreferences prefs;
  const LoginPage({super.key, required this.prefs});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false, hide = true;
  String? error;
  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'أدخل البريد وكلمة المرور'); return;
    }
    setState(() { loading = true; error = null; });
    try {
      await db.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'تعذر الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(children: [
          Container(width: 86, height: 86, decoration: BoxDecoration(color: const Color(0xFF155D4A), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.school_rounded, color: Colors.white, size: 46)),
          const SizedBox(height: 18),
          const Text('لامين', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('لامين لإدارة وتنظيم المدارس', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 32),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 14),
          TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
          if (error != null) ...[const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: loading ? null : login, icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login), label: Text(loading ? 'جارِ الدخول...' : 'دخول'))),
          const SizedBox(height: 18),
          const Text('الحسابات تُدار من Supabase Auth', style: TextStyle(fontSize: 12, color: Colors.black45)),
        ]),
      ),
    ))),
  );
}

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;
  const HomePage({super.key, required this.prefs});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  late final SchoolRepository repo = SchoolRepository(widget.prefs);
  int tab = 0; bool loading = true, online = true;
  SchoolProfile? profile; List<Student> students = []; List<Teacher> teachers = [];
  int subjects = 0, grades = 0; double payments = 0;
  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      profile = await repo.profile();
      students = await repo.students();
      teachers = await repo.teachers();
      subjects = await repo.count('subjects');
      grades = await repo.count('grades');
      payments = await repo.paymentsTotal();
      online = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    final pages = [
      DashboardView(profile: profile, students: students, teachers: teachers, subjects: subjects, grades: grades, payments: payments, online: online, onRefresh: refresh),
      StudentsView(students: students),
      TeachersView(repo: repo, teachers: teachers, onChanged: refresh),
      FinanceView(repo: repo, students: students, payments: payments, onChanged: refresh),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('لامين', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
        IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)),
        PopupMenuButton<String>(onSelected: (v) async { if (v == 'logout') await repo.signOut(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))]),
      ]),
      body: loading ? const Center(child: CircularProgressIndicator()) : pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الطلاب'),
        NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'المعلمون'),
        NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'المالية'),
      ]),
    );
  }
}

class DashboardView extends StatelessWidget {
  final SchoolProfile? profile;
  final List<Student> students;
  final List<Teacher> teachers;
  final int subjects;
  final int grades;
  final double payments;
  final bool online;
  final Future<void> Function() onRefresh;
  const DashboardView({super.key, required this.profile, required this.students, required this.teachers, required this.subjects, required this.grades, required this.payments, required this.online, required this.onRefresh});

  Widget stat(String title, String value, IconData icon) => Card(
    child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFFE7F2ED), child: Icon(icon, color: const Color(0xFF155D4A))),
      title: Text(title),
      trailing: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final welcome = profile?.username.isNotEmpty == true ? 'مرحباً ' + profile!.username : 'مرحباً بك';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF155D4A),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.verified_user, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(online ? 'متصل بالنظام' : 'وضع العمل دون اتصال', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                Text(welcome, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(profile?.role ?? 'مستخدم', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          stat('الطلاب', students.length.toString(), Icons.groups_rounded),
          stat('المعلمون', teachers.length.toString(), Icons.school_rounded),
          stat('المواد', subjects.toString(), Icons.menu_book_rounded),
          stat('الدرجات', grades.toString(), Icons.grade_rounded),
          stat('إجمالي المدفوعات', payments.toStringAsFixed(2) + ' د.ل', Icons.account_balance_wallet_rounded),
          const Card(
            child: ListTile(
              leading: Icon(Icons.security),
              title: Text('حماية البيانات مفعّلة'),
              subtitle: Text('Supabase Auth وRLS يطبقان الوصول حسب المدرسة والصلاحية.'),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentsView extends StatelessWidget {
  final List<Student> students;
  const StudentsView({super.key, required this.students});
  @override Widget build(BuildContext context) => students.isEmpty
    ? const Center(child: Text('لا توجد بيانات طلاب'))
    : ListView.builder(padding: const EdgeInsets.all(12), itemCount: students.length, itemBuilder: (_, i) {
        final s = students[i];
        return Card(margin: const EdgeInsets.symmetric(vertical: 5), child: ListTile(
          leading: CircleAvatar(child: Text(s.name.isEmpty ? '?' : s.name.substring(0, 1))),
          title: Text(s.name),
          subtitle: Text('الفصل: ' + s.className + (s.phone.isEmpty ? '' : ' • ' + s.phone)),
          trailing: IconButton(onPressed: s.phone.isEmpty ? null : () => openWhatsApp(context, s.phone, 'السلام عليكم، نود إبلاغكم بخصوص الطالب.'), icon: const Icon(Icons.chat, color: Color(0xFF155D4A))),
        ));
      });
}

class TeachersView extends StatelessWidget {
  final SchoolRepository repo; final List<Teacher> teachers; final Future<void> Function() onChanged;
  const TeachersView({super.key, required this.repo, required this.teachers, required this.onChanged});
  @override Widget build(BuildContext context) => Stack(children: [
    teachers.isEmpty ? const Center(child: Text('لا توجد بيانات معلمين')) : ListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: teachers.length, itemBuilder: (_, i) {
      final t = teachers[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(t.name), subtitle: Text(t.subject + (t.phone.isEmpty ? '' : ' • ' + t.phone))));
    }),
    Positioned(bottom: 20, right: 20, child: FloatingActionButton.extended(onPressed: () => addTeacher(context), icon: const Icon(Icons.add), label: const Text('معلم'))),
  ]);
  Future<void> addTeacher(BuildContext context) async {
    final name = TextEditingController(), subject = TextEditingController(), phone = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('إضافة معلم'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')), const SizedBox(height: 10),
      TextField(controller: subject, decoration: const InputDecoration(labelText: 'المادة')), const SizedBox(height: 10),
      TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: () async { if (name.text.trim().isEmpty || subject.text.trim().isEmpty) return; await repo.addTeacher(name: name.text, subject: subject.text, phone: phone.text); if (context.mounted) Navigator.pop(context); await onChanged(); }, child: const Text('حفظ')),
    ]));
  }
}

class FinanceView extends StatelessWidget {
  final SchoolRepository repo; final List<Student> students; final double payments; final Future<void> Function() onChanged;
  const FinanceView({super.key, required this.repo, required this.students, required this.payments, required this.onChanged});
  @override Widget build(BuildContext context) => Column(children: [
    Card(margin: const EdgeInsets.all(16), child: ListTile(leading: const Icon(Icons.account_balance_wallet, size: 36, color: Color(0xFF155D4A)), title: const Text('إجمالي المدفوعات'), subtitle: Text(payments.toStringAsFixed(2) + ' د.ل', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)))),
    Expanded(child: students.isEmpty ? const Center(child: Text('أضف الطلاب أولاً لتسجيل المدفوعات')) : ListView.builder(itemCount: students.length, itemBuilder: (_, i) {
      final s = students[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: ListTile(title: Text(s.name), subtitle: Text(s.className), trailing: FilledButton.tonal(onPressed: () => payment(context, s), child: const Text('دفعة'))));
    })),
  ]);
  Future<void> payment(BuildContext context, Student s) async {
    final amount = TextEditingController(), note = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(title: Text('دفعة — ' + s.name), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ د.ل')),
      const SizedBox(height: 10), TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: () async { final v = double.tryParse(amount.text.replaceAll(',', '.')); if (v == null || v <= 0) return; await repo.addPayment(studentId: s.id, amount: v, note: note.text); if (context.mounted) Navigator.pop(context); await onChanged(); }, child: const Text('حفظ')),
    ]));
  }
}
