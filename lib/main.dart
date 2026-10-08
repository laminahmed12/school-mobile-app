import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'لامين',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
      scaffoldBackgroundColor: const Color(0xFFF6F7F4),
      inputDecorationTheme: const InputDecorationTheme(border: UnderlineInputBorder()),
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
    if (!mounted) return;
    setState(() {
      checking = false;
      locked = session != null && enabled;
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
      return HomePage(prefs: widget.prefs);
    },
  );
}

class LoginPage extends StatefulWidget {
  final SharedPreferences prefs;
  const LoginPage({super.key, required this.prefs});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final school=TextEditingController(), username=TextEditingController(), password=TextEditingController(), license=TextEditingController();
  final auth=LaminAuthService();
  bool loading=false,hide=true,schoolLocked=false,showLicense=false;
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
    setState(()=>loading=true);
    final r=await auth.login(school:school.text,username:username.text,password:password.text,licenseCode:license.text);
    if(!mounted)return;
    if(r.trialExpired){setState(()=>showLicense=true);}
    setState(()=>error=r.ok?null:r.message);
    setState(()=>loading=false);
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
        if(showLicense) ...[
          const SizedBox(height:12),
          TextField(controller:license,autocorrect:false,decoration:const InputDecoration(labelText:'رمز الترخيص الدائم',prefixIcon:Icon(Icons.vpn_key_outlined))),
        ],
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
      final response = await db.functions.invoke('owner-api', body: {'action': 'list_schools', 'pin': pin});
      final data = response.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerConsole(pin: pin)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
    final pages = [
      DashboardView(profile: profile, students: students, teachers: teachers, payments: payments, expenses: expenses, online: online),
      StudentsView(repo: repo, students: students, onChanged: refresh),
      AttendanceView(repo: repo, students: students),
      FinanceView(repo: repo, students: students, payments: payments, expenses: expenses, onChanged: refresh),
      MoreView(repo: repo, prefs: widget.prefs, teachers: teachers, students: students, onChanged: refresh),
    ];
    return WillPopScope(
      onWillPop: () async {
        try { await BackupService.backupAndOpenShare(repo); } catch (_) {}
        return true;
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('لامين', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)), PopupMenuButton<String>(onSelected: (v) async { if (v == 'logout') await repo.signOut(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))])]),
      body: loading ? const Center(child: CircularProgressIndicator()) : pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الطلاب'),
        NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'الحضور'),
        NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'المالية'),
        NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'المزيد'),
      ]),
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
  const StudentsView({super.key, required this.repo, required this.students, required this.onChanged});
  @override State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.students.where((s) => s.name.contains(q) || s.className.contains(q) || s.phone.contains(q)).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 5), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => q = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث سريع عن طالب'))), const SizedBox(width: 8), IconButton.filled(onPressed: () => addStudent(context), icon: const Icon(Icons.person_add))])),
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
  Future<void> payment(BuildContext context, Student s) async { final a=TextEditingController(), n=TextEditingController(); await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('دفعة — ${s.name}'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ د.ل')),TextField(controller:n,decoration:const InputDecoration(labelText:'ملاحظة'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',','.'));if(v==null||v<=0)return;try{await repo.addPayment(studentId:s.id,amount:v,note:n.text);if(ctx.mounted)Navigator.pop(ctx);await onChanged();if(s.phone.isNotEmpty&&context.mounted){await openWhatsApp(context,s.phone,'السلام عليكم، تم تسجيل دفعة للطالب ${s.name} بقيمة ${v.toStringAsFixed(2)} د.ل.');}}catch(_){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('تعذر حفظ الدفعة')));}},child:const Text('حفظ'))])); }
}

class UserManagementView extends StatefulWidget {
  final SchoolRepository repo;
  const UserManagementView({super.key,required this.repo});
  @override State<UserManagementView> createState()=>_UserManagementViewState();
}
class _UserManagementViewState extends State<UserManagementView>{
  List<Map<String,dynamic>> users=[]; bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load() async {setState(()=>loading=true);try{users=await widget.repo.schoolUsers();}catch(_){ }if(mounted)setState(()=>loading=false);}
  Future<void> oneDrive(Map<String,dynamic> u) async {
    final id=u['user_id']?.toString()??''; final name=u['username']?.toString()??''; final granted=u['onedrive_access_granted']==true;
    final email=TextEditingController(text:u['microsoft_email']?.toString()??'');
    final token=TextEditingController(); final drive=TextEditingController(); final folder=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:Text(granted?'إلغاء صلاحية OneDrive':'منح صلاحية OneDrive'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('المستخدم: '+name),
        if(!granted) ...[TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'بريد Microsoft / OneDrive')),const SizedBox(height:8),const Text('المنح يتم من حساب مدير المدرسة.',style:TextStyle(fontSize:12))],
        const SizedBox(height:8),TextField(controller:token,obscureText:true,decoration:const InputDecoration(labelText:'رمز Microsoft المؤقت')),
        const SizedBox(height:8),TextField(controller:drive,decoration:const InputDecoration(labelText:'معرّف OneDrive Drive')),
        const SizedBox(height:8),TextField(controller:folder,decoration:const InputDecoration(labelText:'معرّف مجلد المدرسة')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(granted?'إلغاء الصلاحية':'منح الصلاحية'))],
    ))??false;
    if(!ok)return;
    try{
      if(granted){await widget.repo.revokeOneDriveAccess(id,microsoftAccessToken:token.text.trim(),driveId:drive.text.trim(),folderItemId:folder.text.trim());}
      else {if(email.text.trim().isEmpty)throw Exception('أدخل بريد Microsoft');await widget.repo.grantOneDriveAccess(id,microsoftEmail:email.text,microsoftAccessToken:token.text.trim(),driveId:drive.text.trim(),folderItemId:folder.text.trim());}
      await load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(granted?'تم إلغاء صلاحية OneDrive.':'تم منح صلاحية OneDrive.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تنفيذ العملية: '+e.toString())));}
  }
  Future<void> disable(Map<String,dynamic> u) async {
    final role=u['role']?.toString()??'';if(role!='accountant'&&role!='supervisor')return;final id=u['user_id']?.toString()??'';
    if(u['onedrive_access_granted']==true){
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('إيقاف الحساب'),content:Text('سيتم إيقاف حساب '+(u['username']?.toString()??'')+' مع الحفاظ على السجلات.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('إيقاف'))]))??false;
    if(!ok)return;try{final token=TextEditingController();final drive=TextEditingController();final folder=TextEditingController();final credentials=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('تأمين الإيقاف'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('لأن الحساب يملك صلاحية OneDrive، سيقوم لامين بإلغاء المشاركة أولاً ثم يوقف الحساب.'),const SizedBox(height:10),TextField(controller:token,obscureText:true,decoration:const InputDecoration(labelText:'جلسة Microsoft للمدير')),const SizedBox(height:8),TextField(controller:drive,decoration:const InputDecoration(labelText:'معرّف OneDrive Drive')),const SizedBox(height:8),TextField(controller:folder,decoration:const InputDecoration(labelText:'معرّف مجلد المدرسة'))])),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('إلغاء الصلاحية والإيقاف'))]))??false;if(!credentials)return;await widget.repo.disableUserAndRevokeOneDrive(id,microsoftAccessToken:token.text.trim(),driveId:drive.text.trim(),folderItemId:folder.text.trim());await load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إلغاء OneDrive وإيقاف الحساب.')));}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر الإيقاف؛ لم يتم تعطيل الحساب حفاظاً على أمان OneDrive.')));}
  }
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مستخدمو المدرسة'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(12),children:[
    const Card(child:ListTile(leading:Icon(Icons.security),title:Text('حماية OneDrive'),subtitle:Text('المحاسب والمشرف لا يحصلان على التخزين إلا بموافقة المدير.'))),
    ...users.map((u){final role=u['role']=='accountant'?'محاسب':u['role']=='supervisor'?'مشرف':u['role'].toString();final granted=u['onedrive_access_granted']==true;return Card(child:ListTile(leading:CircleAvatar(child:Icon(u['role']=='accountant'?Icons.calculate:Icons.supervisor_account)),title:Text(u['username']?.toString()??'—'),subtitle:Text(role+' • '+(u['active']==true?'نشط':'موقوف')+'\nOneDrive: '+(granted?'مصرّح':'غير مصرح')),isThreeLine:true,trailing:Wrap(children:[IconButton(tooltip:granted?'إلغاء OneDrive':'منح OneDrive',onPressed:u['active']==true?()=>oneDrive(u):null,icon:Icon(granted?Icons.cloud_off:Icons.cloud_done)),if((u['role']=='accountant'||u['role']=='supervisor')&&u['active']==true)IconButton(tooltip:'إيقاف',onPressed:()=>disable(u),icon:const Icon(Icons.person_off))])));}),
  ]));
}
class MoreView extends StatelessWidget {
  final SchoolRepository repo; final SharedPreferences prefs; final List<Teacher> teachers; final List<Student> students; final Future<void> Function() onChanged;
  const MoreView({super.key, required this.repo, required this.prefs, required this.teachers, required this.students, required this.onChanged});
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.all(12),children:[
    Card(child:ListTile(leading:const Icon(Icons.school),title:const Text('المعلمون'),subtitle:Text('${teachers.length} معلم'),onTap:()=>showTeachers(context))),
    Card(child:ListTile(leading:const Icon(Icons.receipt_long),title:const Text('مصروف جديد'),subtitle:const Text('تسجيل مصروف المدرسة'),onTap:()=>expense(context))),
    Card(child:ListTile(leading:const Icon(Icons.analytics_outlined),title:const Text('التقارير اليومية'),subtitle:const Text('حضور وغياب ومدفوعات ومصروفات'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReportsView(repo:repo))))),
    Card(child:ListTile(leading:const Icon(Icons.menu_book),title:const Text('الدرجات والنتائج'),subtitle:const Text('إدخال الدرجات وإرسال النتيجة عبر WhatsApp'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AcademicView(repo:repo,students:students))))),
    Card(child:ListTile(leading:const Icon(Icons.settings),title:const Text('إعداد المدرسة'),subtitle:const Text('السنوات والصفوف والمواد'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SchoolSetupView(repo:repo))))),
    Card(child:ListTile(leading:const Icon(Icons.manage_accounts),title:const Text('مستخدمو المدرسة'),subtitle:const Text('إدارة المشرفين والمحاسبين'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UserManagementView(repo:repo))))),
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
  Future<void> showTeachers(BuildContext context) async { await showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[const Text('المعلمون',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),...teachers.map((t)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(t.name),subtitle:Text(t.subject+(t.phone.isEmpty?'':' • ${t.phone}'))))]))); }
  Future<void> expense(BuildContext context) async { final t=TextEditingController(),a=TextEditingController(),cat=TextEditingController(text:'عام'); await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('مصروف جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'البيان')),TextField(controller:cat,decoration:const InputDecoration(labelText:'التصنيف')),TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ د.ل'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',','.'));if(t.text.trim().isEmpty||v==null||v<=0)return;try{await repo.addExpense(title:t.text,amount:v,category:cat.text);if(ctx.mounted)Navigator.pop(ctx);await onChanged();}catch(_){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('تعذر حفظ المصروف')));}},child:const Text('حفظ'))])); }
}
