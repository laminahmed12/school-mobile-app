import 'package:flutter/material.dart';
import 'models.dart';
import 'repository.dart';
import 'whatsapp.dart';
import 'academic.dart';

class StudentProfileView extends StatefulWidget {
 final SchoolRepository repo; final Student student;
 const StudentProfileView({super.key,required this.repo,required this.student});
 @override State<StudentProfileView> createState()=>_StudentProfileViewState();
}
class _StudentProfileViewState extends State<StudentProfileView>{
 Map<String,dynamic>? parent; bool loading=true;
 @override void initState(){super.initState();load();}
 Future<void> load()async{parent=await widget.repo.parent(widget.student.id);if(mounted)setState(()=>loading=false);}
 @override Widget build(BuildContext c){
  final phone=(parent?['phone']??widget.student.phone).toString();
  final name=(parent?['parent_name']??'').toString();
  final relation=(parent?['relation']??'ولي الأمر').toString();
  return Scaffold(appBar:AppBar(title:const Text('ملف الطالب')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(14),children:[
   Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(widget.student.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(widget.student.className))),
   Card(child:ListTile(leading:const Icon(Icons.phone),title:const Text('ولي الأمر'),subtitle:Text(phone.isEmpty?'غير مسجل':phone),trailing:IconButton(onPressed:phone.isEmpty?null:()=>openWhatsApp(c,phone,'السلام عليكم، بخصوص الطالب '+widget.student.name+'.'),icon:const Icon(Icons.chat)))),
   Card(child:ListTile(leading:const Icon(Icons.family_restroom),title:Text(name.isEmpty?'ولي الأمر':name),subtitle:Text(relation))),
   const SizedBox(height:8),
   FilledButton.icon(onPressed:()=>editParent(c),icon:const Icon(Icons.edit),label:const Text('بيانات ولي الأمر')),
   const SizedBox(height:8),
   OutlinedButton.icon(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>AcademicView(repo:widget.repo,students:[widget.student]))),icon:const Icon(Icons.grade),label:const Text('الدرجات والنتائج')),
  ]);
 }
 Future<void> editParent(BuildContext c)async{
  final n=TextEditingController(text:(parent?['parent_name']??'').toString());
  final p=TextEditingController(text:(parent?['phone']??widget.student.phone).toString());
  final r=TextEditingController(text:(parent?['relation']??'ولي الأمر').toString());
  await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('بيانات ولي الأمر'),content:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:n,decoration:const InputDecoration(labelText:'الاسم')),
   TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'الهاتف / WhatsApp')),
   TextField(controller:r,decoration:const InputDecoration(labelText:'صلة القرابة')),
  ]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{
   final digits=p.text.replaceAll(RegExp(r'[^0-9]'),''); if(digits.isNotEmpty&&digits.length<8)return;
   await widget.repo.saveParent(studentId:widget.student.id,parentName:n.text,phone:digits,relation:r.text);
   if(c.mounted)Navigator.pop(c); await load();
  },child:const Text('حفظ'))]));
 }
}
