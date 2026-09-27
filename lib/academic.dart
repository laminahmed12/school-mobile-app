import 'package:flutter/material.dart';
import 'models.dart';
import 'repository.dart';
import 'whatsapp.dart';

class AcademicView extends StatefulWidget {
 final SchoolRepository repo; final List<Student> students;
 const AcademicView({super.key,required this.repo,required this.students});
 @override State<AcademicView> createState()=>_AcademicViewState();
}
class _AcademicViewState extends State<AcademicView>{
 Student? selected; List<SubjectItem> subjects=[]; List<ResultItem> results=[]; bool loading=false;
 Future<void> openStudent(Student s)async{setState((){selected=s;loading=true;});subjects=await widget.repo.subjects();results=await widget.repo.results(s.id);if(mounted)setState(()=>loading=false);}
 @override Widget build(BuildContext c){
  if(selected==null)return ListView(padding:const EdgeInsets.all(12),children:[
   const Text('الدرجات والنتائج',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:6),
   const Text('اختر الطالب لإدخال الدرجات ومراجعة نتيجته.',style:TextStyle(color:Colors.black54)),const SizedBox(height:12),
   ...widget.students.map((s)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(s.name),subtitle:Text(s.className),trailing:const Icon(Icons.chevron_left),onTap:()=>openStudent(s))))
  ]);
  final percent=results.isEmpty?0:results.fold<double>(0,(a,r)=>a+r.score)/results.fold<double>(0,(a,r)=>a+r.maxScore)*100;
  return Scaffold(appBar:AppBar(title:Text(selected!.name),leading:IconButton(onPressed:()=>setState(()=>selected=null),icon:const Icon(Icons.arrow_back))),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(12),children:[
   Card(child:ListTile(title:const Text('المعدل الحالي'),trailing:Text('${percent.toStringAsFixed(1)}%',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)))),
   FilledButton.icon(onPressed:()=>addResult(c),icon:const Icon(Icons.add),label:const Text('إضافة درجة')),
   const SizedBox(height:8),
   if(results.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد درجات مسجلة بعد.',textAlign:TextAlign.center))),
   ...results.map((r)=>Card(child:ListTile(title:Text(r.examName),subtitle:Text('${r.term} • ${r.score.toStringAsFixed(1)} / ${r.maxScore.toStringAsFixed(1)}'),trailing:Text('${(r.score/r.maxScore*100).toStringAsFixed(0)}%')))),
   if(selected!.phone.isNotEmpty)OutlinedButton.icon(onPressed:()=>openWhatsApp(c,selected!.phone,'السلام عليكم، هذه نتيجة الطالب ${selected!.name}: ${percent.toStringAsFixed(1)}٪.'),icon:const Icon(Icons.chat),label:const Text('إرسال النتيجة عبر WhatsApp'))
  ]);
 }
 Future<void> addResult(BuildContext c)async{
  final exam=TextEditingController(),score=TextEditingController(),max=TextEditingController(text:'100'),term=TextEditingController(text:'الفصل الأول');
  String? subjectId=subjects.isEmpty?null:subjects.first.id;
  await showDialog(context:c,builder:(_)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('درجة جديدة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:exam,decoration:const InputDecoration(labelText:'اسم الاختبار')),
   TextField(controller:term,decoration:const InputDecoration(labelText:'الفصل')),
   if(subjects.isNotEmpty)DropdownButtonFormField<String>(value:subjectId,decoration:const InputDecoration(labelText:'المادة'),items:subjects.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.name))).toList(),onChanged:(v)=>setD(()=>subjectId=v)),
   TextField(controller:score,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الدرجة')),
   TextField(controller:max,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'من'))
 ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()async{
   final sc=double.tryParse(score.text.replaceAll(',','.')),mx=double.tryParse(max.text.replaceAll(',','.'));
   if(exam.text.trim().isEmpty||subjectId==null||sc==null||mx==null||mx<=0||sc<0||sc>mx)return;
   await widget.repo.addResult(studentId:selected!.id,subjectId:subjectId!,term:term.text,exam:exam.text,score:sc,maxScore:mx);
   if(ctx.mounted)Navigator.pop(ctx);await openStudent(selected!);
 },child:const Text('حفظ'))]));
 }
}
