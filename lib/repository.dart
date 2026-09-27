import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'supabase_config.dart';

class SchoolRepository {
  final SharedPreferences prefs;
  SchoolRepository(this.prefs);
  Future<SchoolProfile?> profile() async {
    final u=db.auth.currentUser; if(u==null)return null;
    final row=await db.from('profiles').select().eq('user_id',u.id).maybeSingle();
    return row==null?null:SchoolProfile.fromMap(row);
  }
  Future<List<Student>> students() async {
    try {
      final rows=await db.from('students').select().order('name');
      final list=(rows as List).map((e)=>Student.fromMap(e)).toList();
      await prefs.setString('students_cache',jsonEncode(list.map((e)=>e.toMap()).toList()));
      return list;
    } catch(_) {
      final raw=prefs.getString('students_cache'); if(raw==null)return [];
      return (jsonDecode(raw) as List).map((e)=>Student.fromMap(Map<String,dynamic>.from(e))).toList();
    }
  }
  Future<List<Teacher>> teachers() async {
    try { final rows=await db.from('teachers').select().order('name'); return (rows as List).map((e)=>Teacher.fromMap(e)).toList(); } catch(_){return [];}
  }
  Future<int> count(String table) async { try { final rows=await db.from(table).select('id'); return (rows as List).length; } catch(_){return 0;} }
  Future<double> paymentsTotal() async { try { final rows=await db.from('payments').select('amount'); return (rows as List).fold<double>(0,(s,e)=>s+((e['amount'] as num?)?.toDouble()??0)); } catch(_){return 0;} }
  Future<void> addTeacher({required String name,required String subject,String phone=''}) async { await db.from('teachers').insert({'name':name.trim(),'subject':subject.trim(),'phone':phone.trim()}); }
  Future<void> addPayment({required String studentId,required double amount,String note=''}) async { await db.from('payments').insert({'student_id':studentId,'amount':amount,'note':note.trim()}); }
  Future<void> signOut()=>db.auth.signOut();
}
