import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'repository.dart';
import 'whatsapp.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url:supabaseUrl,publishableKey:supabasePublishableKey);
  final prefs=await SharedPreferences.getInstance();
  runApp(LaminApp(prefs:prefs));
}
class LaminApp extends StatelessWidget {
  final SharedPreferences prefs; const LaminApp({super.key,required this.prefs});
  @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'لامين',theme:ThemeData(useMaterial3:true,fontFamily:'Cairo',colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF155D4A)),scaffoldBackgroundColor:const Color(0xFFF6F7F4)),home:AuthGate(prefs:prefs));
}
class AuthGate extends StatelessWidget {
  final SharedPreferences prefs; const AuthGate({super.key,required this.prefs});
  @override Widget build(BuildContext c)=>StreamBuilder<AuthState>(stream:db.auth.onAuthStateChange,builder:(_,__)=>db.auth.currentSession==null?LoginPage(prefs:prefs):HomePage(prefs:prefs));
}
class LoginPage extends StatefulWidget {
  final SharedPreferences prefs; const LoginPage({super.key,required this.prefs});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final email=TextEditingController(),password=TextEditingController();bool loading=false,hide=true;String? error;
  Future<void> login() async {if(email.text.trim().isEmpty||password.text.isEmpty){setState(()=>error='أدخل البريد وكلمة المرور');return;}setState(()=>loading=true);try{await db.auth.signInWithPassword(email:email.text.trim(),password:password.text);}on AuthException catch(e){setState(()=>error=e.message);}catch(_){setState(()=>error='تعذر الاتصال بالخادم');}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext c)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(children:[
    Container(width:86,height:86,decoration:BoxDecoration(color:const Color(0xFF155D4A),borderRadius:BorderRadius.circular(24)),child:const Icon(Icons.school,color:Colors.white,size:46)),
    const SizedBox(height:18),const Text('لامين',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:5),const Text('لامين لإدارة وتنظيم المدارس',style:TextStyle(color:Colors.black54)),const SizedBox(height:30),
    TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'البريد الإلكتروني',prefixIcon:Icon(Icons.email_outlined))),const SizedBox(height:12),
    TextField(controller:password,obscureText:hide,decoration:InputDecoration(labelText:'كلمة المرور',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility:Icons.visibility_off)))),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red),textAlign:TextAlign.center)),
    const SizedBox(height:18),SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:loading?null:login,icon:loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.login),label:Text(loading?'جارِ الدخول...':'دخول'))),
    const SizedBox(height:16),const Text('سيبقى الدخول محفوظًا على هذا الجهاز حتى تسجيل الخروج أو انتهاء الجلسة الأمنية.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.black45)),const SizedBox(height:6),const Text('Adreemk',style:TextStyle(fontSize:11,color:Colors.black38))
  ])))));
}
}
class HomePage extends StatefulWidget {final SharedPreferences prefs;const HomePage({super.key,required this.prefs});@override State<HomePage> createState()=>_HomePageState();}
class _HomePageState extends State<HomePage>{
  late final repo=SchoolRepository(widget.prefs);int tab=0;bool loading=true,online=true;SchoolProfile? profile;List<Student> students=[];List<Teacher> teachers=[];double payments=0,expenses=0;
  @override void initState(){super.initState();refresh();}
  Future<void> refresh() async {if(mounted)setState(()=>loading=true);try{profile=await repo.profile();students=await repo.students();teachers=await repo.teachers();payments=await repo.paymentsTotal();expenses=await repo.expensesTotal();online=!(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);}catch(_){}if(mounted)setState(()=>loading=false);}
  @override Widget build(BuildContext c){final pages=[DashboardView(profile:profile,students:students,payments:payments,expenses:expenses,online:online),StudentsView(repo:repo,students:students,onChanged:refresh),AttendanceView(repo:repo,students:students),FinanceView(repo:repo,students:students,payments:payments,expenses:expenses,onChanged:refresh),MoreView(repo:repo,teachers:teachers,onChanged:refresh)];
  return Scaffold(appBar:AppBar(title:const Text('لامين',style:TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:loading?null:refresh,icon:const Icon(Icons.refresh)),PopupMenuButton<String>(onSelected:(v)async{if(v=='logout')await repo.signOut();},itemBuilder:(_)=>const[PopupMenuItem(value:'logout',child:Text('تسجيل الخروج'))])]),body:loading?const Center(child:CircularProgressIndicator()):pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
    NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'الرئيسية'),
    NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'الطلاب'),
    NavigationDestination(icon:Icon(Icons.fact_check_outlined),selectedIcon:Icon(Icons.fact_check),label:'الحضور'),
    NavigationDestination(icon:Icon(Icons.payments_outlined),selectedIcon:Icon(Icons.payments),label:'المالية'),
    NavigationDestination(icon:Icon(Icons.more_horiz),selectedIcon:Icon(Icons.more_horiz),label:'المزيد')]));
  }
}
class DashboardView extends StatelessWidget{
  final SchoolProfile? profile;final List<Student> students;final double payments,expenses;final bool online;
  const DashboardView({super.key,required this.profile,required this.students,required this.payments,required this.expenses,required this.online});
  Widget stat(String a,String b,IconData i)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE7F2ED),child:Icon(i,color:const Color(0xFF155D4A))),title:Text(a),trailing:Text(b,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800))));
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(14),children:[
    Card(color:const Color(0xFF155D4A),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(online?'● متصل بالنظام':'● دون اتصال',style:const TextStyle(color:Colors.white)),const SizedBox(height:10),Text(profile?.username.isNotEmpty==true?'مرحباً ${profile!.username}':'مرحباً بك',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800)),Text(profile?.role??'مستخدم',style:const TextStyle(color:Colors.white70))]))),
    stat('الطلاب','${students.length}',Icons.groups),stat('المعلمون','—',Icons.school),stat('إجمالي المدفوعات','${payments.toStringAsFixed(2)} د.ل',Icons.account_balance_wallet),stat('المصروفات','${expenses.toStringAsFixed(2)} د.ل',Icons.receipt_long),
    Card(child:ListTile(leading:const Icon(Icons.security),title:const Text('نظام المدرسة محمي'),subtitle:Text(online?'المزامنة مع Supabase متاحة.':'لا إنترنت: البيانات المحلية الأساسية تبقى متاحة.')))
  ]);
}
class StudentsView extends StatefulWidget{final SchoolRepository repo;final List<Student> students;final Future<void> Function() onChanged;const StudentsView({super.key,required this.repo,required this.students,required this.onChanged});@override State<StudentsView> createState()=>_StudentsViewState();}
class _StudentsViewState extends State<StudentsView>{
  String q='';
  @override Widget build(BuildContext c){final list=students.where((s)=>s.name.contains(q)||s.className.contains(q)||s.phone.contains(q)).toList();return Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(12,12,12,5),child:Row(children:[Expanded(child:TextField(onChanged:(v)=>setState(()=>q=v.trim()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث سريع عن طالب'))),const SizedBox(width:8),IconButton.filled(onPressed:()=>addStudent(c),icon:const Icon(Icons.person_add))])),
    Expanded(child:list.isEmpty?const Center(child:Text('لا توجد نتائج')):ListView.builder(padding:const EdgeInsets.all(10),itemCount:list.length,itemBuilder:(_,i){final s=list[i];return Card(child:ListTile(leading:CircleAvatar(child:Text(s.name.isEmpty?'?':s.name[0])),title:Text(s.name),subtitle:Text(s.className+(s.phone.isEmpty?'':' • '+s.phone)),trailing:IconButton(onPressed:s.phone.isEmpty?null:()=>openWhatsApp(c,s.phone,'السلام عليكم، نود إبلاغكم بخصوص الطالب ${s.name}.'),icon:const Icon(Icons.chat,color:Color(0xFF155D4A))));}))
  ]);}
  Future<void> addStudent(BuildContext c)async{final n=TextEditingController(),cl=TextEditingController(),p=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('طالب جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'اسم الطالب')),TextField(controller:cl,decoration:const InputDecoration(labelText:'الصف / الفصل')),TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'WhatsApp ولي الأمر'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{if(n.text.trim().isEmpty||cl.text.trim().isEmpty)return;await repo.addStudent(name:n.text,className:cl.text,phone:p.text);if(c.mounted)Navigator.pop(c);await widget.onChanged();},child:const Text('حفظ'))]));}
}
class AttendanceView extends StatefulWidget{final SchoolRepository repo;final List<Student> students;const AttendanceView({super.key,required this.repo,required this.students});@override State<AttendanceView> createState()=>_AttendanceViewState();}
class _AttendanceViewState extends State<AttendanceView>{
  final Map<String,String> status={};DateTime day=DateTime.now();bool saving=false;
  Future<void> load()async{final rows=await widget.repo.attendance(day);for(final r in rows)status[r.studentId]=r.status;if(mounted)setState((){});}
  @override void initState(){super.initState();load();}
  Future<void> mark(Student s,String v)async{setState(()=>status[s.id]=v);try{await widget.repo.saveAttendance(studentId:s.id,day:day,status:v);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر حفظ الحضور')));}}
  String label(String s)=>s=='present'?'حاضر':s=='absent'?'غائب':s=='late'?'متأخر':'معذور';
  @override Widget build(BuildContext c)=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text('حضور ${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>setState(()=>day=DateTime.now()),icon:const Icon(Icons.today))])),
    Expanded(child:ListView.builder(itemCount:widget.students.length,itemBuilder:(_,i){final s=widget.students[i];final v=status[s.id]??'present';return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(title:Text(s.name),subtitle:Text(label(v)),trailing:PopupMenuButton<String>(initialValue:v,onSelected:(x)=>mark(s,x),itemBuilder:(_)=>const[PopupMenuItem(value:'present',child:Text('حاضر')),PopupMenuItem(value:'absent',child:Text('غائب')),PopupMenuItem(value:'late',child:Text('متأخر')),PopupMenuItem(value:'excused',child:Text('معذور'))]));}))
  ]);
}
class FinanceView extends StatelessWidget{final SchoolRepository repo;final List<Student> students;final double payments,expenses;final Future<void> Function() onChanged;const FinanceView({super.key,required this.repo,required this.students,required this.payments,required this.expenses,required this.onChanged});
  @override Widget build(BuildContext c)=>Column(children:[Padding(padding:const EdgeInsets.all(12),child(Row(children:[Expanded(child:Card(child:ListTile(title:const Text('الداخل'),trailing:Text(' ${payments.toStringAsFixed(2)} د.ل')))),const SizedBox(width:8),Expanded(child:Card(child:ListTile(title:const Text('المصروف'),trailing:Text(' ${expenses.toStringAsFixed(2)} د.ل'))))])),Expanded(child:ListView.builder(itemCount:students.length,itemBuilder:(_,i){final s=students[i];return ListTile(title:Text(s.name),subtitle:Text(s.className),trailing:FilledButton.tonal(onPressed:()=>payment(c,s),child:const Text('دفعة')));}))]);
  Future<void> payment(BuildContext c,Student s)async{final a=TextEditingController(),n=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:Text('دفعة — ${s.name}'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ د.ل')),TextField(controller:n,decoration:const InputDecoration(labelText:'ملاحظة'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',','.'));if(v==null||v<=0)return;await repo.addPayment(studentId:s.id,amount:v,note:n.text);if(c.mounted)Navigator.pop(c);await onChanged();if(s.phone.isNotEmpty&&c.mounted)openWhatsApp(c,s.phone,'السلام عليكم، تم تسجيل دفعة للطالب ${s.name} بقيمة ${v.toStringAsFixed(2)} د.ل.');},child:const Text('حفظ'))]));}
}
class MoreView extends StatelessWidget{final SchoolRepository repo;final List<Teacher> teachers;final Future<void> Function() onChanged;const MoreView({super.key,required this.repo,required this.teachers,required this.onChanged});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    Card(child:ListTile(leading:const Icon(Icons.school),title:const Text('المعلمون'),subtitle:Text('${teachers.length} معلم'),trailing:const Icon(Icons.chevron_left),onTap:()=>showTeachers(c))),
    Card(child:ListTile(leading:const Icon(Icons.receipt_long),title:const Text('مصروف جديد'),subtitle:const Text('تسجيل مصروف المدرسة'),onTap:()=>expense(c))),
    Card(child:ListTile(leading:const Icon(Icons.menu_book),title:const Text('الدرجات والمواد'),subtitle:const Text('المرحلة التالية في النظام'),trailing:const Icon(Icons.construction_outlined))),
    Card(child:ListTile(leading:const Icon(Icons.admin_panel_settings),title:const Text('الصلاحيات والأمان'),subtitle:const Text('RLS وتسجيل العمليات مفعّلان في قاعدة البيانات.'))),
  ]);
  Future<void> showTeachers(BuildContext c)async{await showModalBottomSheet(context:c,isScrollControlled:true,builder:(_)=>SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[const Text('المعلمون',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),...teachers.map((t)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(t.name),subtitle:Text(t.subject+(t.phone.isEmpty?'':' • '+t.phone))))])));}
  Future<void> expense(BuildContext c)async{final t=TextEditingController(),a=TextEditingController(),cat=TextEditingController(text:'عام');await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('مصروف جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'البيان')),TextField(controller:cat,decoration:const InputDecoration(labelText:'التصنيف')),TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ د.ل'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{final v=double.tryParse(a.text.replaceAll(',','.'));if(t.text.trim().isEmpty||v==null||v<=0)return;await repo.addExpense(title:t.text,amount:v,category:cat.text);if(c.mounted)Navigator.pop(c);await onChanged();},child:const Text('حفظ'))]));}
}
