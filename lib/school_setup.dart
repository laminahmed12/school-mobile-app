import 'package:flutter/material.dart';
import 'repository.dart';

class SchoolSetupView extends StatefulWidget{
 final SchoolRepository repo; const SchoolSetupView({super.key,required this.repo});
 @override State<SchoolSetupView> createState()=>_SchoolSetupViewState();
}
class _SchoolSetupViewState extends State<SchoolSetupView>{
 List<Map<String,dynamic>> years=[],classes=[]; bool loading=true;
 @override void initState(){super.initState();load();}
 Future<void> load()async{years=await widget.repo.academicYears();classes=await widget.repo.classes();if(mounted)setState(()=>loading=false);}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('إعداد المدرسة')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(12),children:[
  Card(child:ListTile(leading:const Icon(Icons.event),title:const Text('السنوات الدراسية'),subtitle:Text('${years.length} سنة'),trailing:IconButton(onPressed:()=>addYear(c),icon:const Icon(Icons.add)))),
  ...years.map((y)=>ListTile(title:Text('${y['name']}'),subtitle:Text((y['active']==true)?'نشطة':'غير نشطة'))),
  Card(child:ListTile(leading:const Icon(Icons.class_),title:const Text('الصفوف والفصول'),subtitle:Text('${classes.length} صف/فصل'),trailing:IconButton(onPressed:()=>addClass(c),icon:const Icon(Icons.add)))),
  ...classes.map((x)=>ListTile(title:Text('${x['name']}'),subtitle:Text('${x['section']??''}'))),
  Card(child:ListTile(leading:const Icon(Icons.menu_book),title:const Text('المواد الدراسية'),subtitle:const Text('إضافة مادة جديدة'),trailing:IconButton(onPressed:()=>addSubject(c),icon:const Icon(Icons.add)))),
 ]));
 Future<void> addYear(BuildContext c)async{final t=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('سنة دراسية'),content:TextField(controller:t,decoration:const InputDecoration(labelText:'مثال: 2026 / 2027')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{if(t.text.trim().isEmpty)return;await widget.repo.addAcademicYear(t.text);if(c.mounted)Navigator.pop(c);await load();},child:const Text('حفظ'))]));}
 Future<void> addClass(BuildContext c)async{final n=TextEditingController(),s=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('صف / فصل'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'الصف')),TextField(controller:s,decoration:const InputDecoration(labelText:'الفصل / الشعبة'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{if(n.text.trim().isEmpty)return;await widget.repo.addClass(name:n.text,section:s.text);if(c.mounted)Navigator.pop(c);await load();},child:const Text('حفظ'))]));}
 Future<void> addSubject(BuildContext c)async{final t=TextEditingController();await showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('مادة دراسية'),content:TextField(controller:t,decoration:const InputDecoration(labelText:'اسم المادة')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()async{if(t.text.trim().isEmpty)return;await widget.repo.addSubject(t.text);if(c.mounted)Navigator.pop(c);},child:const Text('حفظ'))]));}
}
