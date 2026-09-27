class Student {
  final String id, name, className, phone;
  const Student({required this.id,required this.name,required this.className,required this.phone});
  factory Student.fromMap(Map<String,dynamic> m)=>Student(id:'${m['id']}',name:'${m['name']??''}',className:'${m['class_name']??''}',phone:'${m['phone']??''}');
}
class Teacher {
  final String id,name,subject,phone;
  const Teacher({required this.id,required this.name,required this.subject,required this.phone});
  factory Teacher.fromMap(Map<String,dynamic> m)=>Teacher(id:'${m['id']}',name:'${m['name']??''}',subject:'${m['subject']??''}',phone:'${m['phone']??''}');
}
class SchoolProfile {
  final String? schoolId; final String username,role; final bool active,mustChangePassword;
  const SchoolProfile({this.schoolId,required this.username,required this.role,required this.active,required this.mustChangePassword});
  factory SchoolProfile.fromMap(Map<String,dynamic> m)=>SchoolProfile(schoolId:m['school_id'] as String?,username:'${m['username']??''}',role:'${m['role']??''}',active:m['active']??true,mustChangePassword:m['must_change_password']??false);
}
class AttendanceRecord {
  final String studentId,status; final int minutesLate;
  const AttendanceRecord({required this.studentId,required this.status,this.minutesLate=0});
  factory AttendanceRecord.fromMap(Map<String,dynamic> m)=>AttendanceRecord(studentId:'${m['student_id']}',status:'${m['status']}',minutesLate:(m['minutes_late']??0) as int);
}
