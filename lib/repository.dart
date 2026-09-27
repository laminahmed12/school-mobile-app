import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'supabase_config.dart';

class SchoolRepository {
 final SharedPreferences prefs; SchoolRepository(this.prefs);
 Future<SchoolProfile?> profile() async {final u=db.auth.currentUser;if(u==null)return null;final row=await db.from('profiles').select().eq('user_id',u.id).maybeSingle();return row==null?null:SchoolProfile.fromMap(row);}
 Future<List<Student>> students() async {try{final rows=await db.from('students').select().order('name');final list=(rows as List).map((e)=>Student.fromMap(Map<String,dynamic>.from(e))).toList();await prefs.setString('students_cache',jsonEncode(list.map((s)=>{'id':s.id,'name':s.name,'class_name':s.className,'phone':s.phone}).toList()));return list;}catch(_){final raw=prefs.getString('students_cache');if(raw==null)return[];return(jsonDecode(raw)as List).map((e)=>Student.fromMap(Map<String,dynamic>.from(e))).toList();}}
 Future<Map<String,dynamic>?> parent(String studentId) async {
  try {
    final row=await db.from('student_parents').select().eq('student_id',studentId).maybeSingle();
    return row==null?null:Map<String,dynamic>.from(row);
  } catch(_){return null;}
 }
 Future<void> saveParent({required String studentId,required String parentName,required String phone,String relation='ولي الأمر'}) async {
  await db.from('student_parents').upsert({'student_id':studentId,'parent_name':parentName.trim(),'phone':phone.replaceAll(RegExp(r'[^0-9]'),'').trim(),'relation':relation.trim()});
 }
 Future<Map<String,dynamic>> dailySummary(DateTime day) async {
  final d=day.toIso8601String().substring(0,10);
  try {
    final r=await db.rpc('school_daily_summary',params:{'p_date':d});
    return Map<String,dynamic>.from(r as Map);
  } catch(_){return {};}
 }

 Future<List<Map<String,dynamic>>> academicYears()async{try{return (await db.from('academic_years').select().order('created_at',ascending:false) as List).map((e)=>Map<String,dynamic>.from(e)).toList();}catch(_){return[];}}
 Future<List<Map<String,dynamic>>> classes()async{try{return (await db.from('classes').select().order('name') as List).map((e)=>Map<String,dynamic>.from(e)).toList();}catch(_){return[];}}
 Future<void> addAcademicYear(String name)async{await db.from('academic_years').insert({'name':name.trim(),'active':false});}
 Future<void> addClass({required String name,String section='',String? academicYearId})async{await db.from('classes').insert({'name':name.trim(),'section':section.trim(),'academic_year_id':academicYearId});}
 Future<void> addSubject(String name)async{await db.from('subjects').insert({'name':name.trim()});}
 Future<List<Teacher>> teachers()async{try{final rows=await db.from('teachers').select().order('name');return(rows as List).map((e)=>Teacher.fromMap(Map<String,dynamic>.from(e))).toList();}catch(_){return[];}}
 Future<List<SubjectItem>> subjects()async{try{final rows=await db.from('subjects').select().order('name');return(rows as List).map((e)=>SubjectItem.fromMap(Map<String,dynamic>.from(e))).toList();}catch(_){return[];}}
 Future<List<AttendanceRecord>> attendance(DateTime day)async{final d=day.toIso8601String().substring(0,10);try{final rows=await db.from('attendance').select().eq('attendance_date',d);return(rows as List).map((e)=>AttendanceRecord.fromMap(Map<String,dynamic>.from(e))).toList();}catch(_){return[];}}
 Future<void> saveAttendance({required String studentId,required DateTime day,required String status,int minutesLate=0})async{await db.from('attendance').upsert({'student_id':studentId,'attendance_date':day.toIso8601String().substring(0,10),'status':status,'minutes_late':minutesLate});}
 Future<List<ResultItem>> results(String studentId)async{final rows=await db.from('student_results').select().eq('student_id',studentId).order('created_at',ascending:false);return(rows as List).map((e)=>ResultItem.fromMap(Map<String,dynamic>.from(e))).toList();}
 Future<void> addResult({required String studentId,String? subjectId,required String term,required String exam,double score=0,double maxScore=100})async{await db.from('student_results').insert({'student_id':studentId,'subject_id':subjectId,'term':term,'exam_name':exam,'score':score,'max_score':maxScore});}
 Future<int> count(String table)async{try{return(await db.from(table).select('id')as List).length;}catch(_){return 0;}}
 Future<double> paymentsTotal()async{try{return(await db.from('payments').select('amount')as List).fold<double>(0,(x,e)=>x+(e['amount']as num).toDouble());}catch(_){return 0;}}
 Future<double> expensesTotal()async{try{return(await db.from('expenses').select('amount')as List).fold<double>(0,(x,e)=>x+(e['amount']as num).toDouble());}catch(_){return 0;}}
 Future<void> addStudent({required String name,required String className,required String phone})async{await db.from('students').insert({'name':name.trim(),'class_name':className.trim(),'phone':phone.trim()});}
 Future<void> addTeacher({required String name,required String subject,String phone=''})async{await db.from('teachers').insert({'name':name.trim(),'subject':subject.trim(),'phone':phone.trim()});}
 Future<void> addPayment({required String studentId,required double amount,String note=''})async{await db.from('payments').insert({'student_id':studentId,'amount':amount,'note':note.trim()});}
 Future<void> addExpense({required String title,required double amount,String category='عام',String note=''})async{await db.from('expenses').insert({'title':title.trim(),'amount':amount,'category':category.trim(),'note':note.trim()});}
 Future<void> queueWhatsApp({required String studentId,required String phone,required String kind,required String message})async{await db.from('whatsapp_notifications').insert({'student_id':studentId,'phone':phone,'kind':kind,'message':message});}
 Future<void> signOut()=>db.auth.signOut();
}