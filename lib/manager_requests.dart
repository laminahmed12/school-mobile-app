import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' show PdfGoogleFonts;
import 'supabase_config.dart';
import 'repository.dart';

class ManagerRequestsView extends StatefulWidget {
  final SchoolRepository repo;
  const ManagerRequestsView({super.key, required this.repo});
  @override
  State<ManagerRequestsView> createState() => _ManagerRequestsViewState();
}

class _ManagerRequestsViewState extends State<ManagerRequestsView> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  bool loading = true, saving = false;
  String? schoolId, yearId;
  List<Map<String,dynamic>> years=[], students=[], teachers=[], teacherRecords=[], charges=[], plans=[], installments=[];
  @override void initState(){super.initState(); load();}
  @override void dispose(){tabs.dispose();super.dispose();}

  Future<void> load() async {
    setState(()=>loading=true);
    try {
      final school=await widget.repo.school();
      schoolId=school?['id']?.toString();
      years=(await widget.repo.academicYears()).map((e)=>Map<String,dynamic>.from(e)).toList();
      yearId ??= years.where((e)=>e['active']==true).firstOrNull?['id']?.toString() ?? years.firstOrNull?['id']?.toString();
      students=(await db.from('students').select('id,name,class_name').order('name') as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      teachers=(await db.from('teachers').select('id,name,subject,phone,salary').order('name') as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      if(schoolId!=null && yearId!=null){
        teacherRecords=(await db.from('teacher_academic_year_records').select().eq('school_id',schoolId!).eq('academic_year_id',yearId!).order('created_at',ascending:false) as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        charges=(await db.from('student_extra_charges').select().eq('school_id',schoolId!).eq('academic_year_id',yearId!).order('created_at',ascending:false) as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        plans=(await db.from('student_payment_plans').select().eq('school_id',schoolId!).eq('academic_year_id',yearId!).order('created_at',ascending:false) as List).map((e)=>Map<String,dynamic>.from(e)).toList();
        final ids=plans.map((e)=>e['id'].toString()).toList();
        installments=ids.isEmpty?[]:(await db.from('student_payment_installments').select().eq('school_id',schoolId!).inFilter('plan_id',ids).order('installment_number') as List).map((e)=>Map<String,dynamic>.from(e)).toList();
      }
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل بيانات الإدارة المالية: $e'))); }
    if(mounted)setState(()=>loading=false);
  }

  String studentName(dynamic id)=>students.where((s)=>s['id'].toString()==id.toString()).map((s)=>s['name'].toString()).firstOrNull??'طالب';
  String teacherName(dynamic id)=>teachers.where((s)=>s['id'].toString()==id.toString()).map((s)=>s['name'].toString()).firstOrNull??'معلم';

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('متطلبات الإدارة المدرسية'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))],
      bottom:TabBar(controller:tabs,isScrollable:true,tabs:const [Tab(text:'المعلمون حسب العام'),Tab(text:'رسوم وغرامات'),Tab(text:'خطط التحصيل')]),
    ),
    body:loading?const Center(child:CircularProgressIndicator()):Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:DropdownButtonFormField<String>(
        initialValue:yearId,decoration:const InputDecoration(labelText:'العام الدراسي'),
        items:years.map((y)=>DropdownMenuItem(value:y['id'].toString(),child:Text(y['name'].toString()))).toList(),
        onChanged:(v){setState(()=>yearId=v);load();},
      )),
      Expanded(child:TabBarView(controller:tabs,children:[
        _list(teacherRecords.map((r)=>ListTile(title:Text(teacherName(r['teacher_id'])),subtitle:Text('المادة: ${r['subject']??'—'} • الراتب: ${r['salary']??'—'} د.ل • ${r['active']==true?'نشط':'غير نشط'}'))).toList(),
          'إضافة معلم لهذا العام',addTeacherYear),
        _list(charges.map((r)=>ListTile(title:Text('${r['title']} — ${studentName(r['student_id'])}'),subtitle:Text('${_type(r['charge_type'])} • ${r['amount']} د.ل • ${r['incident_date']??''}'),trailing:IconButton(icon:const Icon(Icons.print_outlined),onPressed:()=>printClaim(r)))).toList(),
          'إضافة رسم أو غرامة',addCharge),
        _list(plans.map((r){final ins=installments.where((i)=>i['plan_id']==r['id']).toList();return Card(child:ExpansionTile(title:Text('${studentName(r['student_id'])} — ${r['title']}'),subtitle:Text('الإجمالي: ${r['total_amount']} د.ل • ${ins.length} دفعات'),children:[...ins.map((i)=>ListTile(title:Text('دفعة ${i['installment_number']} — ${i['amount']} د.ل'),subtitle:Text('تستحق: ${i['due_date']}'))),TextButton.icon(onPressed:()=>printPlan(r,ins),icon:const Icon(Icons.print),label:const Text('طباعة المطالبة'))]));}).toList(),
          'إنشاء خطة تحصيل',addPlan),
      ]))
    ]),
  );

  Widget _list(List<Widget> rows,String label,VoidCallback action)=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving?null:action,icon:const Icon(Icons.add),label:Text(label)))),
    Expanded(child:rows.isEmpty?const Center(child:Text('لا توجد سجلات لهذا العام.')):ListView(padding:const EdgeInsets.all(12),children:rows))
  ]);

  String _type(dynamic t)=>switch(t){'transport'=>'مواصلات','tutoring'=>'تقويات','damage'=>'غرامة إتلاف','other'=>'رسم إضافي',_=>'رسم'};

  Future<void> addTeacherYear() async {
    if(teachers.isEmpty||yearId==null||schoolId==null)return;
    String tid=teachers.first['id'].toString(); final subject=TextEditingController(text:teachers.first['subject']?.toString()??''); final salary=TextEditingController(text:teachers.first['salary']?.toString()??''); final phone=TextEditingController(text:teachers.first['phone']?.toString()??''); bool active=true;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('بيانات المعلم لهذا العام'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(initialValue:tid,items:teachers.map((t)=>DropdownMenuItem(value:t['id'].toString(),child:Text(t['name'].toString()))).toList(),onChanged:(v){if(v!=null)setD(()=>tid=v);}),
      TextField(controller:subject,decoration:const InputDecoration(labelText:'المادة')),
      TextField(controller:salary,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الراتب الشهري')),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'الهاتف')),
      SwitchListTile(value:active,onChanged:(v)=>setD(()=>active=v),title:const Text('نشط في هذا العام')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))])));
    if(ok!=true)return;
    await _save(()=>db.from('teacher_academic_year_records').upsert({'school_id':schoolId,'teacher_id':tid,'academic_year_id':yearId,'subject':subject.text.trim(),'salary':double.tryParse(salary.text.replaceAll(',','.')),'phone':phone.text.trim(),'active':active},onConflict:'school_id,teacher_id,academic_year_id'));
  }

  Future<void> addCharge() async {
    if(students.isEmpty||yearId==null||schoolId==null)return;
    String sid=students.first['id'].toString(), type='transport'; final title=TextEditingController(); final amount=TextEditingController(); final date=TextEditingController(text:DateTime.now().toIso8601String().substring(0,10)); final note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('رسم إضافي أو غرامة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(initialValue:sid,items:students.map((s)=>DropdownMenuItem(value:s['id'].toString(),child:Text(s['name'].toString()))).toList(),onChanged:(v){if(v!=null)sid=v;}),
      DropdownButtonFormField<String>(initialValue:type,items:const [DropdownMenuItem(value:'transport',child:Text('مواصلات')),DropdownMenuItem(value:'tutoring',child:Text('تقويات')),DropdownMenuItem(value:'damage',child:Text('غرامة إتلاف')),DropdownMenuItem(value:'other',child:Text('رسم إضافي'))],onChanged:(v){if(v!=null)type=v;}),
      TextField(controller:title,decoration:const InputDecoration(labelText:'البيان (مثال: إتلاف مقعد)')),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ بالدينار الليبي')),
      TextField(controller:date,decoration:const InputDecoration(labelText:'التاريخ YYYY-MM-DD')),
      TextField(controller:note,decoration:const InputDecoration(labelText:'ملاحظات')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));
    final v=double.tryParse(amount.text.replaceAll(',','.'));if(ok!=true||v==null||v<=0||title.text.trim().isEmpty)return;
    await _save(()=>db.from('student_extra_charges').insert({'school_id':schoolId,'student_id':sid,'academic_year_id':yearId,'charge_type':type,'title':title.text.trim(),'amount':v,'incident_date':date.text.trim().isEmpty?null:date.text.trim(),'notes':note.text.trim()}));
  }

  Future<void> addPlan() async {
    if(students.isEmpty||yearId==null||schoolId==null)return;
    String sid=students.first['id'].toString(); final title=TextEditingController(text:'خطة سداد الرسوم'); final total=TextEditingController(); final count=TextEditingController(text:'2'); final firstDate=TextEditingController(text:DateTime.now().toIso8601String().substring(0,10));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('خطة تحصيل على دفعات'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(initialValue:sid,items:students.map((s)=>DropdownMenuItem(value:s['id'].toString(),child:Text(s['name'].toString()))).toList(),onChanged:(v){if(v!=null)sid=v;}),
      TextField(controller:title,decoration:const InputDecoration(labelText:'اسم الخطة')),
      TextField(controller:total,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'القيمة الكاملة')),
      TextField(controller:count,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'عدد الدفعات')),
      TextField(controller:firstDate,decoration:const InputDecoration(labelText:'موعد الدفعة الأولى YYYY-MM-DD')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إنشاء'))]));
    final amount=double.tryParse(total.text.replaceAll(',','.'));final n=int.tryParse(count.text);final start=DateTime.tryParse(firstDate.text.trim());
    if(ok!=true||amount==null||amount<=0||n==null||n<2||n>24||start==null||title.text.trim().isEmpty)return;
    setState(()=>saving=true);
    try {
      final plan=await db.from('student_payment_plans').insert({'school_id':schoolId,'student_id':sid,'academic_year_id':yearId,'title':title.text.trim(),'total_amount':amount}).select('id').single();
      final base=(amount/n*100).floorToDouble()/100; final rows=<Map<String,dynamic>>[];
      for(var i=1;i<=n;i++){final due=DateTime(start.year,start.month+i-1,start.day);rows.add({'school_id':schoolId,'plan_id':plan['id'],'installment_number':i,'amount':i==n?double.parse((amount-base*(n-1)).toStringAsFixed(2)):base,'due_date':due.toIso8601String().substring(0,10)});}
      await db.from('student_payment_installments').insert(rows); await load();
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشل إنشاء الخطة: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> _save(Future<dynamic> Function() action) async {setState(()=>saving=true);try{await action();await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الحفظ: $e')));}finally{if(mounted)setState(()=>saving=false);}}

  Future<void> printClaim(Map<String,dynamic> charge) async {
    final doc=pw.Document();final font=await PdfGoogleFonts.notoNaskhArabicRegular();final bold=await PdfGoogleFonts.notoNaskhArabicBold();
    doc.addPage(pw.Page(pageFormat:PdfPageFormat.a4,theme:pw.ThemeData.withFont(base:font,bold:bold),build:(_)=>pw.Directionality(textDirection:pw.TextDirection.rtl,child:pw.Padding(padding:const pw.EdgeInsets.all(32),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
      pw.Text('مطالبة مالية مدرسية',style:pw.TextStyle(font: bold,fontSize:24)),pw.SizedBox(height:24),
      pw.Text('الطالب: ${studentName(charge['student_id'])}'),pw.Text('العام الدراسي: ${years.where((y)=>y['id'].toString()==yearId).map((y)=>y['name']).firstOrNull??''}'),
      pw.Text('البيان: ${charge['title']}'),pw.Text('النوع: ${_type(charge['charge_type'])}'),pw.Text('المبلغ المطلوب: ${charge['amount']} د.ل'),pw.Text('التاريخ: ${charge['incident_date']??''}'),pw.SizedBox(height:40),pw.Text('توقيع الإدارة: ____________________')
    ]))));
    await Printing.layoutPdf(onLayout:(_)=>doc.save());
  }
  Future<void> printPlan(Map<String,dynamic> plan,List<Map<String,dynamic>> ins) async {
    final doc=pw.Document();final font=await PdfGoogleFonts.notoNaskhArabicRegular();final bold=await PdfGoogleFonts.notoNaskhArabicBold();
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,theme:pw.ThemeData.withFont(base:font,bold:bold),build:(_)=>[
      pw.Directionality(textDirection:pw.TextDirection.rtl,child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
        pw.Text('مطالبة مالية وخطة سداد',style:pw.TextStyle(font:bold,fontSize:24)),pw.SizedBox(height:14),
        pw.Text('الطالب: ${studentName(plan['student_id'])}'),pw.Text('الخطة: ${plan['title']}'),pw.Text('الإجمالي: ${plan['total_amount']} د.ل'),pw.SizedBox(height:12),
        pw.TableHelper.fromTextArray(headers:['رقم الدفعة','المبلغ (د.ل)','تاريخ الاستحقاق'],data:ins.map((i)=>['${i['installment_number']}','${i['amount']}','${i['due_date']}']).toList()),
        pw.SizedBox(height:30),pw.Text('توقيع ولي الأمر: ____________________     توقيع الإدارة: ____________________')
      ]))
    ]));
    await Printing.layoutPdf(onLayout:(_)=>doc.save());
  }
}
