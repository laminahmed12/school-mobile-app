import 'package:flutter/material.dart';
import 'repository.dart';

class ReportsView extends StatefulWidget{
 final SchoolRepository repo; const ReportsView({super.key,required this.repo});
 @override State<ReportsView> createState()=>_ReportsViewState();
}
class _ReportsViewState extends State<ReportsView>{
 DateTime day=DateTime.now(); Map<String,dynamic> data={}; bool loading=false;
 @override void initState(){super.initState();load();}
 Future<void> load()async{setState(()=>loading=true);data=await widget.repo.dailySummary(day);if(mounted)setState(()=>loading=false);}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('التقارير اليومية')),body:ListView(padding:const EdgeInsets.all(14),children:[
  Card(child:ListTile(leading:const Icon(Icons.calendar_today),title:Text('${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:c,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDate:day);if(d!=null){day=d;load();}},icon:const Icon(Icons.edit_calendar)))),
  if(loading)const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator())),
  if(!loading&&data.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('تعذر تحميل التقرير.'))),
  if(!loading&&data.isNotEmpty)...[
   row('إجمالي الطلاب',data['students']),row('الحاضرون',data['present']),row('الغائبون',data['absent']),row('المتأخرون',data['late']),row('المدفوعات','${data['payments']??0} د.ل'),row('المصروفات','${data['expenses']??0} د.ل')
  ]
 ]);
 Widget row(String a,d)=>Card(child:ListTile(title:Text(a),trailing:Text('$d',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold))));
}
