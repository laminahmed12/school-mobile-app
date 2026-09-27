class Student {
  final String id, name, className, phone;
  const Student({required this.id, required this.name, required this.className, required this.phone});
  factory Student.fromMap(Map<String,dynamic> m) => Student(id:m['id'] as String, name:(m['name']??'') as String, className:(m['class_name']??'') as String, phone:(m['phone']??'') as String);
  Map<String,dynamic> toMap()=>{'id':id,'name':name,'class_name':className,'phone':phone};
}
class Teacher {
  final String id, name, subject, phone;
  const Teacher({required this.id,required this.name,required this.subject,required this.phone});
  factory Teacher.fromMap(Map<String,dynamic> m)=>Teacher(id:m['id'] as String,name:(m['name']??'') as String,subject:(m['subject']??'') as String,phone:(m['phone']??'') as String);
}
class SchoolProfile {
  final String? schoolId; final String username, role; final bool active, mustChangePassword;
  const SchoolProfile({this.schoolId,required this.username,required this.role,required this.active,required this.mustChangePassword});
  factory SchoolProfile.fromMap(Map<String,dynamic> m)=>SchoolProfile(schoolId:m['school_id'] as String?,username:(m['username']??'') as String,role:(m['role']??'') as String,active:(m['active']??true) as bool,mustChangePassword:(m['must_change_password']??false) as bool);
}
