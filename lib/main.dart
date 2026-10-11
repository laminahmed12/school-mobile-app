import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'app_error.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'biometric_service.dart';
import 'models.dart';
import 'repository.dart';
import 'supabase_config.dart';
import 'whatsapp.dart';
import 'academic.dart';
import 'student_profile.dart';
import 'reports.dart';
import 'school_setup.dart';
import 'owner_console.dart';
import 'auth_service.dart';
import 'backup_service.dart';

const brandGreen = Color(0xFF155D4A);
const brandGold = Color(0xFFD7B56D);
const brandInk = Color(0xFF20312C);
const brandCanvas = Color(0xFFF3F6F3);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(LaminApp(prefs: prefs));
}

class LaminApp extends StatelessWidget {
  final SharedPreferences prefs;
  const LaminApp({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'لامين',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: brandGreen,
        secondary: brandGold,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: brandCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandCanvas,
        foregroundColor: brandInk,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: brandInk.withValues(alpha: 0.10),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFE7F0EA),
        indicatorColor: const Color(0xFFCBE8DA),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E1DA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandGreen, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    ),
    home: AuthGate(prefs: prefs),
  );
}

class AuthGate extends StatefulWidget {
  final SharedPreferences prefs;
  const AuthGate({super.key, required this.prefs});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final security = DeviceSecurityService();
  bool locked = false;
  bool checking = true;
  bool mustChangePassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLock();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (db.auth.currentSession != null && mounted) setState(() => locked = true);
    }
  }

  Future<void> _refreshLock() async {
    final session = db.auth.currentSession;
    final enabled = await security.enabled;
    bool forcePassword = false;
    if (session != null) {
      try {
        final row = await db.from('profiles')
            .select('role,must_change_password,active')
            .eq('user_id', session.user.id)
            .maybeSingle();
        forcePassword = row?['active'] == true &&
            row?['role'] != 'owner' &&
            row?['must_change_password'] == true;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      checking = false;
      locked = session != null && enabled;
      mustChangePassword = forcePassword;
    });
  }

  void _unlock() {
    if (mounted) setState(() => locked = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: db.auth.onAuthStateChange,
    builder: (_, __) {
      if (db.auth.currentSession == null) return LoginPage(prefs: widget.prefs);
      if (checking || locked) return DeviceLockPage(onAuthenticated: _unlock);
      if (mustChangePassword) return ForcePasswordChangePage(prefs: widget.prefs);
      return HomePage(prefs: widget.prefs);
    },
  );
}

class ForcePasswordChangePage extends StatefulWidget {
  final SharedPreferences prefs;
  const ForcePasswordChangePage({super.key, required this.prefs});
  @override State<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool loading = false, hide = true, hideConfirm = true;
  String? error;

  Future<void> save() async {
    final p = password.text;
    if (p.length < 6 || p.length > 72 || p.contains(RegExp(r'\s'))) {
      setState(() => error = 'كلمة المرور يجب أن تكون من 6 إلى 72 خانة وبدون مسافات.');
      return;
    }
    if (p != confirm.text) {
      setState(() => error = 'تأكيد كلمة المرور غير مطابق.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final response = await db.functions.invoke('admin-api', body: {
        'action': 'change_my_password',
        'new_password': p,
      });
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(prefs: widget.prefs)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    await db.auth.signOut();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تغيير كلمة المرور'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: loading ? null : logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 82, height: 82,
                    decoration: BoxDecoration(
                      color: brandGreen,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.lock_reset, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'حماية الحساب',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يجب تغيير كلمة المرور المؤقتة قبل متابعة استخدام المدرسة.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: password,
                    obscureText: hide,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: loading ? null : () => setState(() => hide = !hide),
                        icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: hideConfirm,
                    enabled: !loading,
                    onSubmitted: (_) => save(),
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: loading ? null : () => setState(() => hideConfirm = !hideConfirm),
                        icon: Icon(hideConfirm ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: loading ? null : save,
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(loading ? 'جارِ الحفظ...' : 'حفظ كلمة المرور'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final SharedPreferences prefs;
  const LoginPage({super.key, required this.prefs});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final school=TextEditingController(), username=TextEditingController(), password=TextEditingController();
  final auth=LaminAuthService();
  bool loading=false,hide=true,schoolLocked=false;
  String? error;
  int _ownerTaps = 0;
  DateTime? _lastOwnerTap;

  @override
  void initState(){super.initState();_loadSchool();}
  Future<void> _loadSchool() async {
    final saved=await auth.savedSchoolCode();
    if(!mounted)return;
    if(saved!=null&&saved.isNotEmpty){school.text=saved;setState(()=>schoolLocked=true);}
  }

  Future<void> login() async {
    if (school.text.trim().isEmpty || username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'أدخل رمز المدرسة واسم المستخدم وكلمة المرور.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final r = await auth.login(school: school.text, username: username.text, password: password.text);
      if (!mounted) return;
      setState(() => error = r.ok ? null : (r.trialExpired
          ? 'المدرسة غير مفعّلة حالياً. يرجى التواصل مع مسؤول لامين لتفعيلها.'
          : r.message));
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e, fallback: 'تعذر تسجيل الدخول.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override Widget build(BuildContext context)=>Scaffold(
    body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:430),
      child:Column(children:[
        Container(width:86,height:86,decoration:BoxDecoration(color:brandGreen,borderRadius:BorderRadius.circular(24)),child:const Icon(Icons.school,color:Colors.white,size:46)),
        const SizedBox(height:18),const Text('لامين',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),
        const SizedBox(height:5),const Text('لامين لإدارة وتنظيم المدارس'),
        const SizedBox(height:30),const Align(alignment:Alignment.centerRight,child:Text('دخول المدرسة',style:TextStyle(fontWeight:FontWeight.w700))),
        const SizedBox(height:8),
        TextField(controller:school,enabled:!schoolLocked,autocorrect:false,decoration:InputDecoration(labelText:'رمز المدرسة',prefixIcon:const Icon(Icons.domain),suffixIcon:schoolLocked?IconButton(onPressed:()=>setState(()=>schoolLocked=false),icon:const Icon(Icons.edit)):null)),
        const SizedBox(height:12),
        TextField(controller:username,autocorrect:false,decoration:const InputDecoration(labelText:'اسم المستخدم',prefixIcon:Icon(Icons.person_outline))),
        const SizedBox(height:12),
        TextField(controller:password,obscureText:hide,decoration:InputDecoration(labelText:'كلمة المرور',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility:Icons.visibility_off)))),
        if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.red))),
        const SizedBox(height:18),
        SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:loading?null:login,icon:loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.login),label:Text(loading?'جارِ الدخول...':'دخول'))),
        const SizedBox(height:14),
        const Text('سيتم حفظ رمز المدرسة بأمان على هذا الجهاز بعد أول دخول ناجح.',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
        const SizedBox(height: 22),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final now = DateTime.now();
            if (_lastOwnerTap == null ||
                now.difference(_lastOwnerTap!) > const Duration(milliseconds: 900)) {
              _ownerTaps = 1;
            } else {
              _ownerTaps++;
            }
            _lastOwnerTap = now;
            if (_ownerTaps >= 3) {
              _ownerTaps = 0;
              showDialog(
                context: context,
                builder: (_) => _OwnerPinDialog(prefs: widget.prefs),
              );
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Adreemk', style: TextStyle(fontSize: 11)),
          ),
        ),
      ]),
    )))),
  );
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
  bool loading = false;

  Future<void> openOwner() async {
    final pin = code.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رمز المالك المكوّن من 6 أرقام')));
      return;
    }
    setState(() => loading = true);
    try {
      final response = await db.functions.invoke('owner-api', body: {'action': 'list_schools', 'pin': pin}).timeout(const Duration(seconds: 20));
      final data = response.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerConsole(pin: pin)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: 'تعذر فتح بوابة المالك. حاول مرة أخرى.'))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('بوابة المالك'),
    content: TextField(
      controller: code,
      obscureText: hide,
      keyboardType: TextInputType.number,
      maxLength: 6,
      enabled: !loading,
      onSubmitted: (_) => openOwner(),
      decoration: InputDecoration(
        labelText: 'رمز المالك',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: loading ? null : () => setState(() => hide = !hide),
          icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: loading ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: loading ? null : openOwner, child: Text(loading ? 'جارِ التحقق...' : 'فتح')),
    ],
  );
}

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;
  final int initialTab;
  const HomePage({super.key, required this.prefs, this.initialTab = 0});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final SchoolRepository repo = SchoolRepository(widget.prefs);
  late int tab = widget.initialTab;
  bool loading = true, online = true;
  SchoolProfile? profile;
  List<Student> students = [];
  List<Teacher> teachers = [];
  double payments = 0, expenses = 0;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); refresh(); }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      BackupService.createLocalBackup(repo).then((_) {}, onError: (_) {});
    }
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      await repo.ensureOwnerSchool();
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
    final role = profile?.role ?? '';
    final isAdmin = role == 'admin' || role == 'owner';
    final isSupervisor = role == 'supervisor';
    final isAccountant = role == 'accountant';
    final pages = <Widget>[
      DashboardView(profile: profile, students: students, teachers: teachers, payments: payments, expenses: expenses, online: online),
      if (isAdmin || isSupervisor) StudentsView(repo: repo, students: students, onChanged: refresh, canAdd: isAdmin || isSupervisor),
      if (isAdmin || isSupervisor) AttendanceView(repo: repo, students: students),
      if (isAdmin || isAccountant) FinanceView(repo: repo, students: students, payments: payments, expenses: expenses, onChanged: refresh),
      MoreView(repo: repo, prefs: widget.prefs, teachers: teachers, students: students, onChanged: refresh, role: role),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
      if (isAdmin || isSupervisor) const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الطلاب'),
      if (isAdmin || isSupervisor) const NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'الحضور'),
      if (isAdmin || isAccountant) const NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'المالية'),
      const NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'المزيد'),
    ];
    if (tab >= pages.length) tab = 0;
    return WillPopScope(
      onWillPop: () async {
        try { await BackupService.backupAndOpenShare(repo); } catch (_) {}
        return true;
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('لامين', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)), PopupMenuButton<String>(onSelected: (v) async { if (v == 'logout') { try { await repo.signOut(); if (db.auth.currentSession != null) { throw Exception('لم يكتمل تسجيل الخروج. حاول مرة أخرى.'); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: 'تعذر تسجيل الخروج.')))); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))])]),
      body: loading ? const Center(child: CircularProgressIndicator()) : pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: destinations),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  final SchoolProfile? profile;
  final List<Student> students;
  final List<Teacher> teachers;
  final double payments, expenses;
  final bool online;
  const DashboardView({super.key, required this.profile, required this.students, required this.teachers, required this.payments, required this.expenses, required this.online});
  Widget stat(String title, String value, IconData icon) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(title), trailing: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))));
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
    Card(color: brandGreen, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(online ? '● متصل بالنظام' : '● دون اتصال', style: const TextStyle(color: Colors.white)), const SizedBox(height: 8), Text(profile?.username.isNotEmpty == true ? 'مرحباً ${profile!.username}' : 'مرحباً بك', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), Text(profile?.role ?? 'مستخدم', style: const TextStyle(color: Colors.white70))]))),
    stat('الطلاب', '${students.length}', Icons.groups),
    stat('المعلمون', '${teachers.length}', Icons.school),
    stat('إجمالي المدفوعات', '${payments.toStringAsFixed(2)} د.ل', Icons.account_balance_wallet),
    stat('المصروفات', '${expenses.toStringAsFixed(2)} د.ل', Icons.receipt_long),
  ]);
}

class StudentsView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  final Future<void> Function() onChanged;
  final bool canAdd;
  const StudentsView({super.key, required this.repo, required this.students, required this.onChanged, this.canAdd = true});
  @override State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.students.where((s) => s.name.contains(q) || s.className.contains(q) || s.phone.contains(q)).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 5), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => q = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث سريع عن طالب'))), if (widget.canAdd) ...[const SizedBox(width: 8), IconButton.filled(onPressed: () => addStudent(context), icon: const Icon(Icons.person_add))]])),
      Expanded(child: list.isEmpty ? const Center(child: Text('لا توجد نتائج')) : ListView.builder(padding: const EdgeInsets.all(10), itemCount: list.length, itemBuilder: (_, i) { final s = list[i]; return Card(child: ListTile(leading: CircleAvatar(child: Text(s.name.isEmpty ? '?' : s.name[0])), title: Text(s.name), subtitle: Text(s.className + (s.phone.isEmpty ? '' : ' • ${s.phone}')), trailing: IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileView(repo: widget.repo, student: s))), icon: const Icon(Icons.chevron_left)))); }))
    ]);
  }
  Future<void> addStudent(BuildContext context) async {
    final n = TextEditingController(), cl = TextEditingController(), p = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('طالب جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'اسم الطالب')), TextField(controller: cl, decoration: const InputDecoration(labelText: 'الصف / الفصل')), TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp ولي الأمر'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () async { if (n.text.trim().isEmpty || cl.text.trim().isEmpty) return; try { await widget.repo.addStudent(name: n.text, className: cl.text, phone: p.text); if (ctx.mounted) Navigator.pop(ctx); await widget.onChanged(); } catch (_) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تعذر حفظ الطالب'))); } }, child: const Text('حفظ'))]));
  }
}

class AttendanceView extends StatefulWidget {
  final SchoolRepository repo; final List<Student> students;
  const AttendanceView({super.key, required this.repo, required this.students});
  @override State<AttendanceView> createState() => _AttendanceViewState();
}
class _AttendanceViewState extends State<AttendanceView> {
  final Map<String, String> status = {}; DateTime day = DateTime.now();
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { final rows = await widget.repo.attendance(day); for (final r in rows) { status[r.studentId] = r.status; } if (mounted) setState(() {}); }
  Future<void> mark(Student s, String value) async { setState(() => status[s.id] = value); try { await widget.repo.saveAttendance(studentId: s.id, day: day, status: value); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الحضور'))); } }
  String label(String v) => v == 'present' ? 'حاضر' : v == 'absent' ? 'غائب' : v == 'late' ? 'متأخر' : 'معذور';
  @override Widget build(BuildContext context) { final date = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}'; return Column(children: [Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: Text('حضور $date', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), IconButton(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: day); if (d != null) { day = d; status.clear(); await load(); } }, icon: const Icon(Icons.calendar_today))])), Expanded(child: ListView.builder(itemCount: widget.students.length, itemBuilder: (_, i) { final s = widget.students[i], v = status[s.id] ?? 'present'; return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(title: Text(s.name), subtitle: Text(label(v)), trailing: PopupMenuButton<String>(onSelected: (x) => mark(s, x), itemBuilder: (_) => const [PopupMenuItem(value:'present',child:Text('حاضر')),PopupMenuItem(value:'absent',child:Text('غائب')),PopupMenuItem(value:'late',child:Text('متأخر')),PopupMenuItem(value:'excused',child:Text('معذور'))]))); }))]); }
}

class FinanceView extends StatelessWidget {
  final SchoolRepository repo; final List<Student> students; final double payments, expenses; final Future<void> Function() onChanged;
  const FinanceView({super.key, required this.repo, required this.students, required this.payments, required this.expenses, required this.onChanged});
  @override Widget build(BuildContext context) => Column(children: [Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: Card(child: ListTile(title: const Text('الداخل'), trailing: Text('${payments.toStringAsFixed(2)} د.ل')))), const SizedBox(width:8), Expanded(child: Card(child: ListTile(title: const Text('المصروف'), trailing: Text('${expenses.toStringAsFixed(2)} د.ل'))))])), Expanded(child: ListView.builder(itemCount: students.length, itemBuilder: (_, i) { final s=students[i]; return ListTile(title:Text(s.name),subtitle:Text(s.className),trailing:FilledButton.tonal(onPressed:()=>payment(context,s),child:const Text('دفعة'))); }))]);
  Future<void> payment(BuildContext context, Student s) async { final a=TextEditingController(), n=TextEditingController(); await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('دفعة — ${s.name}'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ د.ل')),TextField(controller:n,decoration:const InputDecoration(labelText:'ملاحظة'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',','.'));if(v==null||v<=0)return;try{await repo.addPayment(studentId:s.id,amount:v,note:n.text);if(ctx.mounted)Navigator.pop(ctx);await onChanged();if(s.phone.isNotEmpty&&context.mounted){await openWhatsApp(context,s.phone,'السلام عليكم، تم تسجيل دفعة للطالب ${s.name} بقيمة ${v.toStringAsFixed(2)} د.ل.');}}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر حفظ الدفعة.'))));}},child:const Text('حفظ'))])); }
}

class UserManagementView extends StatefulWidget {
  final SchoolRepository repo;
  const UserManagementView({super.key, required this.repo});
  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  List<Map<String, dynamic>> users = [];
  bool loading = true, saving = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try { users = await widget.repo.schoolUsers(); } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _adminCall(String action, [Map<String, dynamic> fields = const {}]) async {
    final response = await db.functions.invoke('admin-api', body: {'action': action, ...fields})
        .timeout(const Duration(seconds: 20));
    final data = response.data;
    if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
    if (data is! Map || data['ok'] != true) throw Exception('لم يؤكد الخادم نجاح العملية.');
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin': return 'مدير المدرسة';
      case 'supervisor': return 'مشرف';
      case 'accountant': return 'محاسب';
      case 'owner': return 'مالك النظام';
      default: return role ?? 'غير محدد';
    }
  }

  Future<void> editUser({Map<String, dynamic>? user}) async {
    final username = TextEditingController(text: user?['username']?.toString() ?? '');
    final password = TextEditingController();
    String role = user?['role']?.toString() == 'admin' ? 'admin'
        : (user?['role']?.toString() == 'accountant' ? 'accountant' : 'supervisor');
    final formKey = GlobalKey<FormState>();
    final isNew = user == null;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(isNew ? 'إضافة مستخدم' : 'تعديل المستخدم'),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: username, autocorrect: false, decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            validator: (v) => v == null || v.trim().length < 2 || v.trim().length > 40 ? 'الاسم من 2 إلى 40 حرفاً' : null),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: role,
            decoration: const InputDecoration(labelText: 'الدور والصلاحيات'),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('مدير المدرسة')),
              DropdownMenuItem(value: 'supervisor', child: Text('مشرف')),
              DropdownMenuItem(value: 'accountant', child: Text('محاسب')),
            ],
            onChanged: (value) { if (value != null) setDialogState(() => role = value); },
          ),
          const SizedBox(height: 10),
          TextFormField(controller: password, obscureText: true, decoration: InputDecoration(
            labelText: isNew ? 'كلمة المرور المؤقتة' : 'كلمة مرور جديدة (اختياري)',
            helperText: isNew ? 'سيُطلب منه تغييرها عند أول دخول.' : 'اتركها فارغة دون تغيير.',
          ), validator: (v) {
            if (isNew && (v == null || v.length < 6 || v.length > 72 || v.contains(RegExp(r'\s')))) return 'كلمة المرور 6 خانات على الأقل وبدون مسافات';
            if (v != null && v.isNotEmpty && (v.length < 6 || v.length > 72 || v.contains(RegExp(r'\s')))) return 'كلمة المرور 6 خانات على الأقل وبدون مسافات';
            return null;
          }),
        ]))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: saving ? null : () async {
            if (!formKey.currentState!.validate()) return;
            if (mounted) setState(() => saving = true);
            try {
              if (isNew) {
                await _adminCall('create_user', {'username': username.text.trim(), 'password': password.text, 'role': role});
              } else {
                await _adminCall('update_user', {
                  'user_id': user['user_id'], 'username': username.text.trim(), 'role': role,
                  if (password.text.isNotEmpty) 'password': password.text,
                });
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(friendlyError(e, fallback: 'تعذر حفظ المستخدم.')), backgroundColor: Colors.red.shade700));
            } finally {
              if (mounted) setState(() => saving = false);
            }
          }, child: Text(saving ? 'جارِ الحفظ...' : (isNew ? 'إضافة' : 'حفظ'))),
        ],
      ),
    )) ?? false;
    username.dispose();
    password.dispose();
    if (confirmed) {
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        isNew ? 'تم إنشاء المستخدم؛ يجب تغيير كلمة المرور عند أول دخول.' : 'تم تحديث بيانات المستخدم.')));
    }
  }

  Future<void> toggleActive(Map<String, dynamic> user) async {
    final active = user['active'] == true;
    final name = user['username']?.toString() ?? 'المستخدم';
    final confirmed = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: Text(active ? 'إيقاف الحساب' : 'تفعيل الحساب'),
      content: Text(active ? 'سيُمنع ' + name + ' من الدخول مع الاحتفاظ بسجلاته.' : 'سيُسمح لـ ' + name + ' بالدخول مجدداً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(active ? 'إيقاف' : 'تفعيل')),
      ],
    )) ?? false;
    if (!confirmed) return;
    try {
      await _adminCall('update_user', {'user_id': user['user_id'], 'active': !active});
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(active ? 'تم إيقاف الحساب.' : 'تم تفعيل الحساب.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final name = user['username']?.toString() ?? 'المستخدم';
    final confirmed = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('حذف المستخدم'),
      content: Text('هل تريد حذف حساب ' + name + ' نهائياً؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف')),
      ],
    )) ?? false;
    if (!confirmed) return;
    try {
      await _adminCall('delete_user', {'user_id': user['user_id']});
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المستخدم.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> oneDrive(Map<String, dynamic> u) async {
    final id = u['user_id']?.toString() ?? '';
    final name = u['username']?.toString() ?? '';
    final granted = u['onedrive_access_granted'] == true;
    final email = TextEditingController(text: u['microsoft_email']?.toString() ?? '');
    final token = TextEditingController(), drive = TextEditingController(), folder = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: Text(granted ? 'إلغاء صلاحية OneDrive' : 'منح صلاحية OneDrive'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('المستخدم: ' + name),
        if (!granted) TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'بريد Microsoft / OneDrive')),
        const SizedBox(height: 8),
        TextField(controller: token, obscureText: true, decoration: const InputDecoration(labelText: 'رمز Microsoft المؤقت')),
        const SizedBox(height: 8),
        TextField(controller: drive, decoration: const InputDecoration(labelText: 'معرّف OneDrive Drive')),
        const SizedBox(height: 8),
        TextField(controller: folder, decoration: const InputDecoration(labelText: 'معرّف مجلد المدرسة')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(granted ? 'إلغاء الصلاحية' : 'منح الصلاحية')),
      ],
    )) ?? false;
    if (!ok) return;
    try {
      if (granted) {
        await widget.repo.revokeOneDriveAccess(id, microsoftAccessToken: token.text.trim(), driveId: drive.text.trim(), folderItemId: folder.text.trim());
      } else {
        if (email.text.trim().isEmpty) throw Exception('أدخل بريد Microsoft');
        await widget.repo.grantOneDriveAccess(id, microsoftEmail: email.text, microsoftAccessToken: token.text.trim(), driveId: drive.text.trim(), folderItemId: folder.text.trim());
      }
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(granted ? 'تم إلغاء صلاحية OneDrive.' : 'تم منح صلاحية OneDrive.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مستخدمو المدرسة'), actions: [
      IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: saving ? null : () => editUser(),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('إضافة مستخدم'),
    ),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        const Card(child: ListTile(
          leading: Icon(Icons.security),
          title: Text('الأدوار والصلاحيات'),
          subtitle: Text('مدير المدرسة لإدارة الحسابات، المشرف للمتابعة، والمحاسب للشؤون المالية. صلاحيات OneDrive تدار بشكل منفصل.'),
        )),
        ...users.map((u) {
          final role = _roleLabel(u['role']?.toString());
          final granted = u['onedrive_access_granted'] == true;
          final isOwner = u['role'] == 'owner';
          final active = u['active'] == true;
          return Card(child: ListTile(
            leading: CircleAvatar(child: Icon(u['role'] == 'accountant' ? Icons.calculate : u['role'] == 'supervisor' ? Icons.supervisor_account : Icons.admin_panel_settings)),
            title: Text(u['username']?.toString() ?? '—'),
            subtitle: Text(role + ' • ' + (active ? 'نشط' : 'موقوف') + '\nOneDrive: ' + (granted ? 'مصرّح' : 'غير مصرح')),
            isThreeLine: true,
            trailing: isOwner ? const Icon(Icons.shield) : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') editUser(user: u);
                if (value == 'active') toggleActive(u);
                if (value == 'delete') deleteUser(u);
                if (value == 'drive') oneDrive(u);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات والدور')),
                PopupMenuItem(value: 'active', child: Text(active ? 'إيقاف الحساب' : 'تفعيل الحساب')),
                const PopupMenuItem(value: 'drive', child: Text('إدارة صلاحية OneDrive')),
                const PopupMenuItem(value: 'delete', child: Text('حذف المستخدم')),
              ],
            ),
          ));
        }),
      ],
    ),
  );
}

class MoreView extends StatelessWidget {
  final SchoolRepository repo; final SharedPreferences prefs; final List<Teacher> teachers; final List<Student> students; final Future<void> Function() onChanged; final String role;
  const MoreView({super.key, required this.repo, required this.prefs, required this.teachers, required this.students, required this.onChanged, required this.role});
  @override Widget build(BuildContext context) {
    final isAdmin = role == 'admin' || role == 'owner';
    final isSupervisor = role == 'supervisor';
    final isAccountant = role == 'accountant';
    return ListView(padding:const EdgeInsets.all(12),children:[
    if (isAdmin) Card(child:ListTile(leading:const Icon(Icons.school),title:const Text('المعلمون'),subtitle:Text('${teachers.length} معلم'),onTap:()=>showTeachers(context))),
    if (isAdmin || isAccountant) Card(child:ListTile(leading:const Icon(Icons.receipt_long),title:const Text('مصروف جديد'),subtitle:const Text('تسجيل مصروف المدرسة'),onTap:()=>expense(context))),
    if (isAdmin || isAccountant) Card(child:ListTile(leading:const Icon(Icons.analytics_outlined),title:const Text('التقارير اليومية'),subtitle:const Text('حضور وغياب ومدفوعات ومصروفات'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReportsView(repo:repo))))),
    if (isAdmin || isSupervisor) Card(child:ListTile(leading:const Icon(Icons.menu_book),title:const Text('الدرجات والنتائج'),subtitle:const Text('إدخال الدرجات وإرسال النتيجة عبر WhatsApp'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AcademicView(repo:repo,students:students))))),
    if (isAdmin) Card(child:ListTile(leading:const Icon(Icons.settings),title:const Text('إعداد المدرسة'),subtitle:const Text('السنوات والصفوف والمواد'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SchoolSetupView(repo:repo))))),
    if (isAdmin) Card(child:ListTile(leading:const Icon(Icons.manage_accounts),title:const Text('مستخدمو المدرسة'),subtitle:const Text('إدارة المسؤولين والمشرفين والمحاسبين'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UserManagementView(repo:repo))))),
    Card(child:ListTile(leading:const Icon(Icons.fingerprint),title:const Text('الدخول بالبصمة'),subtitle:const Text('فتح التطبيق بسرعة وبشكل آمن بعد أول دخول'),onTap:()async{
      final service=DeviceSecurityService();
      final enabled=await service.enabled;
      if(!context.mounted)return;
      if(enabled){
        await service.disable();
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تعطيل الدخول بالبصمة.')));
      }else{
        final ok=await service.enable();
        if(!context.mounted)return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'تم تفعيل الدخول بالبصمة.':'لم يتم التفعيل. تأكد من إعداد بصمة على الجهاز.')));
      }
    })),
    ]);
  }
  Future<void> showTeachers(BuildContext context) async { await showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[const Text('المعلمون',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),...teachers.map((t)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(t.name),subtitle:Text(t.subject+(t.phone.isEmpty?'':' • ${t.phone}'))))]))); }
  Future<void> expense(BuildContext context) async { final t=TextEditingController(),a=TextEditingController(),cat=TextEditingController(text:'عام'); await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('مصروف جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'البيان')),TextField(controller:cat,decoration:const InputDecoration(labelText:'التصنيف')),TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ د.ل'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',','.'));if(t.text.trim().isEmpty||v==null||v<=0)return;try{await repo.addExpense(title:t.text,amount:v,category:cat.text);if(ctx.mounted)Navigator.pop(ctx);await onChanged();}catch(_){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('تعذر حفظ المصروف')));}},child:const Text('حفظ'))])); }
}
