import 'package:flutter/foundation.dart';
import 'app_error.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class LaminAuthResult {
  final bool ok;
  final String message;
  final bool trialExpired;
  const LaminAuthResult({required this.ok, required this.message, this.trialExpired = false});
}
class LaminAuthService {
  static const _schoolKey='lamin.school.code';
  static const _storage=FlutterSecureStorage();
  Future<String?> savedSchoolCode()=>_storage.read(key:_schoolKey);
  Future<void> saveSchoolCode(String code)=>_storage.write(key:_schoolKey,value:code.trim());
  Future<void> clearSchoolCode()=>_storage.delete(key:_schoolKey);
  Future<LaminAuthResult> login({required String school,required String username,required String password,String licenseCode=''}) async {
    if(school.trim().isEmpty||username.trim().isEmpty||password.isEmpty)return const LaminAuthResult(ok:false,message:'أدخل رمز المدرسة واسم المستخدم وكلمة المرور.');
    try{
      final res=await db.functions.invoke('auth-login',body:{'school':school.trim(),'username':username.trim(),'password':password,if(licenseCode.trim().isNotEmpty)'license_code':licenseCode.trim()}).timeout(const Duration(seconds: 20));
      final data=Map<String,dynamic>.from(res.data as Map); final refresh=data['refresh_token']?.toString()??'';
      if(refresh.isEmpty)return const LaminAuthResult(ok:false,message:'استجابة الدخول غير مكتملة.');
      await db.auth.setSession(refresh); await saveSchoolCode(school); return const LaminAuthResult(ok:true,message:'تم تسجيل الدخول.');
    }on FunctionException catch(e){
      final d=e.details; if(d is Map){final code=d['code']?.toString()??'';final msg=d['error']?.toString()??'تعذر تسجيل الدخول.';return LaminAuthResult(ok:false,message:msg,trialExpired:code=='TRIAL_EXPIRED');}
      return LaminAuthResult(ok:false,message:friendlyError(e,fallback:'تعذر تسجيل الدخول.'));
    }catch(e){debugPrint('login error: '+e.toString());return LaminAuthResult(ok:false,message:friendlyError(e,fallback:'تعذر تسجيل الدخول.'));}
  }
}
