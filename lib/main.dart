import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'repository.dart';
import 'supabase_config.dart';
import 'whatsapp.dart';
import 'academic.dart';
import 'student_profile.dart';
import 'reports.dart';
import 'school_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(LaminApp(prefs: prefs));
}

class LaminApp extends StatelessWidget {
  final SharedPreferences prefs;
  const LaminApp({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'لامين',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155D4A)),
        scaffoldBackgroundColor: const Color(0xFFF6F7F4),
      ),
      home: AuthGate(prefs: prefs),
    );
  }
}

class AuthGate extends StatelessWidget {
  final SharedPreferences prefs;
  const AuthGate({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        return db.auth.currentSession == null
            ? LoginPage(prefs: prefs)
            : HomePage(prefs: prefs);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  final SharedPreferences prefs;
  const LoginPage({super.key, required this.prefs});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hide = true;
  String? error;
  int ownerTaps = 0;
  DateTime? lastOwnerTap;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'أدخل البريد وكلمة المرور');
      return;
    }
    setState(() => loading = true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 86, height: 86,
                    decoration: BoxDecoration(color: const Color(0xFF155D4A), borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.school, color: Colors.white, size: 46),
                  ),
                  const SizedBox(height: 18),
                  const Text('لامين', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('لامين لإدارة وتنظيم المدارس'),
                  const SizedBox(height: 30),
                  TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: hide,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hide = !hide),
                        icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton.icon(
                      onPressed: loading ? null : login,
                      icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
                      label: Text(loading ? 'جارِ الدخول...' : 'دخول'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('سيبقى الدخول محفوظًا على هذا الجهاز حتى تسجيل الخروج أو انتهاء الجلسة الأمنية.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final now = DateTime.now();
                      if (lastOwnerTap == null ||
                          now.difference(lastOwnerTap!) > const Duration(milliseconds: 900)) {
                        ownerTaps = 1;
                      } else {
                        ownerTaps++;
                      }
                      lastOwnerTap = now;
                      if (ownerTaps >= 3) {
                        ownerTaps = 0;
                        showDialog(
                          context: context,
                          builder: (ctx) => _OwnerPinDialog(prefs: widget.prefs),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Adreemk', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerPinDialog extends StatefulWidget {
  final SharedPreferences prefs;
  const _OwnerPinDialog({required this.prefs});
  @override
  State<_OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<_OwnerPinDialog> {
  final code = TextEditingController();
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بوابة المالك'),
      content: TextField(
        controller: code,
        obscureText: hide,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: InputDecoration(
          labelText: 'رمز المالك',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () => setState(() => hide = !hide),
            icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (code.text.trim() == '116936') {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OwnerPanel(prefs: widget.prefs)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('رمز المالك غير صحيح')),
              );
            }
          },
          child: const Text('فتح'),
        ),
      ],
    );
  }
}

class OwnerPanel extends StatelessWidget {
  final SharedPreferences prefs;
  const OwnerPanel({super.key, required this.prefs});

  Future<void> openOwnerGate(BuildContext context) async {
    final code = TextEditingController();
    var hide = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('بوابة المالك'),
          content: TextField(
            controller: code,
            obscureText: hide,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'رمز المالك',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setDialogState(() => hide = !hide),
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, code.text.trim() == '116936'),
              child: const Text('فتح'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OwnerPanel(prefs: prefs)),
      );
    } else if (ok == false && context.mounted && code.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز المالك غير صحيح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة المالك', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: const Color(0xFF155D4A),
            child: const ListTile(
              leading: CircleAvatar(child: Icon(Icons.admin_panel_settings)),
              title: Text('لوحة المالك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('إدارة ومراجعة إعدادات تطبيق لامين', style: TextStyle(color: Colors.white70)),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('إعداد المدرسة'),
              subtitle: const Text('السنوات والصفوف والمواد'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SchoolSetupView(repo: SchoolRepository(prefs)),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('معلومات النظام'),
              subtitle: const Text('لامين لإدارة وتنظيم المدارس • Adreemk'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('بوابة المالك'),
              subtitle: const Text('الدخول محمي برمز المالك'),
              onTap: () => openOwnerGate(context),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;
  const HomePage({super.key, required this.prefs});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SchoolRepository repo = SchoolRepository(widget.prefs);
  int tab = 0;
  bool loading = true;
  bool online = true;
  SchoolProfile? profile;
  List<Student> students = [];
  List<Teacher> teachers = [];
  double payments = 0;
  double expenses = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      profile = await repo.profile();
      students = await repo.students();
      teachers = await repo.teachers();
      payments = await repo.paymentsTotal();
      expenses = await repo.expensesTotal();
      final status = await Connectivity().checkConnectivity();
      online = !status.contains(ConnectivityResult.none);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardView(profile: profile, students: students, payments: payments, expenses: expenses, online: online),
      StudentsView(repo: repo, students: students, onChanged: refresh),
      AttendanceView(repo: repo, students: students),
      FinanceView(repo: repo, students: students, payments: payments, expenses: expenses, onChanged: refresh),
      MoreView(repo: repo, teachers: teachers, students: students, onChanged: refresh),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('لامين', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            onSelected: (v) async { if (v == 'logout') await repo.signOut(); },
            itemBuilder: (context) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))],
          ),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الطلاب'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'الحضور'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'المالية'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  final SchoolProfile? profile;
  final List<Student> students;
  final double payments;
  final double expenses;
  final bool online;
  const DashboardView({super.key, required this.profile, required this.students, required this.payments, required this.expenses, required this.online});

  Widget stat(String title, String value, IconData icon) {
    return Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(title), trailing: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          color: const Color(0xFF155D4A),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(online ? '● متصل بالنظام' : '● دون اتصال', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              Text(profile?.username.isNotEmpty == true ? 'مرحباً ' + profile!.username : 'مرحباً بك', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(profile?.role ?? 'مستخدم', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
        stat('الطلاب', students.length.toString(), Icons.groups),
        stat('المعلمون', teachersText(), Icons.school),
        stat('إجمالي المدفوعات', payments.toStringAsFixed(2) + ' د.ل', Icons.account_balance_wallet),
        stat('المصروفات', expenses.toStringAsFixed(2) + ' د.ل', Icons.receipt_long),
      ],
    );
  }

  String teachersText() => '—';
}

class StudentsView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  final Future<void> Function() onChanged;
  const StudentsView({super.key, required this.repo, required this.students, required this.onChanged});
  @override State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.students.where((s) => s.name.contains(q) || s.className.contains(q) || s.phone.contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
          child: Row(children: [
            Expanded(child: TextField(onChanged: (v) => setState(() => q = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث سريع عن طالب'))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: () => addStudent(context), icon: const Icon(Icons.person_add)),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا توجد نتائج'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(s.name.isEmpty ? '?' : s.name[0])),
                        title: Text(s.name),
                        subtitle: Text(s.className + (s.phone.isEmpty ? '' : ' • ' + s.phone)),
                        trailing: IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileView(repo: widget.repo, student: s))),
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> addStudent(BuildContext context) async {
    final n = TextEditingController();
    final cl = TextEditingController();
    final p = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طالب جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'اسم الطالب')),
          TextField(controller: cl, decoration: const InputDecoration(labelText: 'الصف / الفصل')),
          TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp ولي الأمر')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (n.text.trim().isEmpty || cl.text.trim().isEmpty) return;
              await widget.repo.addStudent(name: n.text, className: cl.text, phone: p.text);
              if (ctx.mounted) Navigator.pop(ctx);
              await widget.onChanged();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class AttendanceView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  const AttendanceView({super.key, required this.repo, required this.students});
  @override State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final Map<String, String> status = {};
  DateTime day = DateTime.now();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final rows = await widget.repo.attendance(day);
    for (final r in rows) { status[r.studentId] = r.status; }
    if (mounted) setState(() {});
  }

  Future<void> mark(Student s, String value) async {
    setState(() => status[s.id] = value);
    try {
      await widget.repo.saveAttendance(studentId: s.id, day: day, status: value);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الحضور')));
    }
  }

  String label(String value) => value == 'present' ? 'حاضر' : value == 'absent' ? 'غائب' : value == 'late' ? 'متأخر' : 'معذور';

  @override
  Widget build(BuildContext context) {
    final date = day.year.toString() + '-' + day.month.toString().padLeft(2, '0') + '-' + day.day.toString().padLeft(2, '0');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Text('حضور ' + date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: day);
                if (d != null) { day = d; status.clear(); await load(); }
              },
              icon: const Icon(Icons.calendar_today),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.students.length,
            itemBuilder: (context, i) {
              final s = widget.students[i];
              final v = status[s.id] ?? 'present';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text(label(v)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (x) => mark(s, x),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'present', child: Text('حاضر')),
                      PopupMenuItem(value: 'absent', child: Text('غائب')),
                      PopupMenuItem(value: 'late', child: Text('متأخر')),
                      PopupMenuItem(value: 'excused', child: Text('معذور')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FinanceView extends StatelessWidget {
  final SchoolRepository repo;
  final List<Student> students;
  final double payments;
  final double expenses;
  final Future<void> Function() onChanged;
  const FinanceView({super.key, required this.repo, required this.students, required this.payments, required this.expenses, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Card(child: ListTile(title: const Text('الداخل'), trailing: Text(payments.toStringAsFixed(2) + ' د.ل')))),
            const SizedBox(width: 8),
            Expanded(child: Card(child: ListTile(title: const Text('المصروف'), trailing: Text(expenses.toStringAsFixed(2) + ' د.ل')))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, i) {
              final s = students[i];
              return ListTile(
                title: Text(s.name),
                subtitle: Text(s.className),
                trailing: FilledButton.tonal(onPressed: () => payment(context, s), child: const Text('دفعة')),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> payment(BuildContext context, Student s) async {
    final a = TextEditingController();
    final n = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('دفعة — ' + s.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ د.ل')),
          TextField(controller: n, decoration: const InputDecoration(labelText: 'ملاحظة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(a.text.replaceAll(',', '.'));
              if (v == null || v <= 0) return;
              await repo.addPayment(studentId: s.id, amount: v, note: n.text);
              if (ctx.mounted) Navigator.pop(ctx);
              await onChanged();
              if (s.phone.isNotEmpty && context.mounted) {
                await openWhatsApp(context, s.phone, 'السلام عليكم، تم تسجيل دفعة للطالب ' + s.name + ' بقيمة ' + v.toStringAsFixed(2) + ' د.ل.');
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class MoreView extends StatelessWidget {
  final SchoolRepository repo;
  final List<Teacher> teachers;
  final List<Student> students;
  final Future<void> Function() onChanged;
  const MoreView({super.key, required this.repo, required this.teachers, required this.students, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(child: ListTile(leading: const Icon(Icons.school), title: const Text('المعلمون'), subtitle: Text(teachers.length.toString() + ' معلم'), onTap: () => showTeachers(context))),
        Card(child: ListTile(leading: const Icon(Icons.receipt_long), title: const Text('مصروف جديد'), subtitle: const Text('تسجيل مصروف المدرسة'), onTap: () => expense(context))),
        Card(child: ListTile(leading: const Icon(Icons.analytics_outlined), title: const Text('التقارير اليومية'), subtitle: const Text('حضور وغياب ومدفوعات ومصروفات'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsView(repo: repo))))),
        Card(child: ListTile(leading: const Icon(Icons.menu_book), title: const Text('الدرجات والنتائج'), subtitle: const Text('إدخال الدرجات وإرسال النتيجة عبر WhatsApp'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AcademicView(repo: repo, students: students))))),
        Card(child: ListTile(leading: const Icon(Icons.settings), title: const Text('إعداد المدرسة'), subtitle: const Text('السنوات والصفوف والمواد'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolSetupView(repo: repo))))),
      ],
    );
  }

  Future<void> showTeachers(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('المعلمون', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ...teachers.map((t) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(t.name),
              subtitle: Text(t.subject + (t.phone.isEmpty ? '' : ' • ' + t.phone)),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> expense(BuildContext context) async {
    final t = TextEditingController();
    final a = TextEditingController();
    final cat = TextEditingController(text: 'عام');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مصروف جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: const InputDecoration(labelText: 'البيان')),
          TextField(controller: cat, decoration: const InputDecoration(labelText: 'التصنيف')),
          TextField(controller: a, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ د.ل')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(a.text.replaceAll(',', '.'));
              if (t.text.trim().isEmpty || v == null || v <= 0) return;
              await repo.addExpense(title: t.text, amount: v, category: cat.text);
              if (ctx.mounted) Navigator.pop(ctx);
              await onChanged();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
