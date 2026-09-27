import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'supabase_config.dart';

class SchoolRepository {
  final SharedPreferences prefs;
  SchoolRepository(this.prefs);
  Future<SchoolProfile?> profile() async {
    final u=db.auth.currentUser;if(u==null)return null;
    final row=await db.from('profiles').select().eq('user_id',u.id).maybeSingle();
    return row==null?null:SchoolProfile.fromMap(row);
  }
  Future<List<Student>> students() async {
    try {
      final rows=await db.from('students').select().order('name');
      final list=(rows as List).map((e)=>Student.fromMap(Map<String,dynamic>.from(e))).toList();
      await prefs.setString('students_cache',jsonEncode(list.map((s)=>{'id':s.id,'name':s.name,'class_name':s.className,'phone':s.phone}).toList()));
      return list;
    } catch (_) {
      final raw=prefs.getString('students_cache');if(raw==null)return [];
      return (jsonDecode(raw) as List).map((e)=>Student.fromMap(Map<String,dynamic>.from(e))).toList();
    }
  }
  Future<List<Teacher>> teachers() async {
    try {final rows=await db.from('teachers').select().order('name');return (rows as List).map((e)=>Teacher.fromMap(Map<String,dynamic>.from(e))).toList();}catch(_){return[];}
  }
  Future<int> count(String table) async {try{return (await db.from(table).select('id') as List).length;}catch(_){return 0;}}
  Future<double> paymentsTotal() async {try{return (await db.from('payments').select('amount') as List).fold<double>(0,(x,e)=>x+(e['amount'] as num).toDouble());}catch(_){return 0;}}
  Future<double> expensesTotal() async {try{return (await db.from('expenses').select('amount') as List).fold<double>(0,(x,e)=>x+(e['amount'] as num).toDouble());}catch(_){return 0;}}
  Future<List<AttendanceRecord>> attendance(DateTime day) async {
    final d=day.toIso8601String().substring(0,10);
    try {final rows=await db.from('attendance').select().eq('attendance_date',d);return (rows as List).map((e)=>AttendanceRecord.fromMap(Map<String,dynamic>.from(e))).toList();}catch(_){return[];}
  }
  Future<void> saveAttendance({required String studentId,required DateTime day,required String status,int minutesLate=0}) async {
    await db.from('attendance').upsert({'student_id':studentId,'attendance_date':day.toIso8601String().substring(0,10),'status':status,'minutes_late':minutesLate});
  }
  Future<void> addStudent({required String name,required String className,required String phone}) async {
    await db.from('students').insert({'name':name.trim(),'class_name':className.trim(),'phone':phone.trim()});
  }
  Future<void> addTeacher({required String name,required String subject,String phone=''}) async {await db.from('teachers').insert({'name':name.trim(),'subject':subject.trim(),'phone':phone.trim()});}
  Future<void> addPayment({required String studentId,required double amount,String note=''}) async {await db.from('payments').insert({'student_id':studentId,'amount':amount,'note':note.trim()});}
  Future<void> addExpense({required String title,required double amount,String category='عام',String note=''}) async {await db.from('expenses').insert({'title':title.trim(),'amount':amount,'category':category.trim(),'note':note.trim()});}
  Future<void> queueWhatsApp({required String studentId,required String phone,required String kind,required String message}) async {
    await db.from('whatsapp_notifications').insert({'student_id':studentId,'phone':phone,'kind':kind,'message':message});
  }
  Future<void> signOut()=>db.auth.signOut();
}
