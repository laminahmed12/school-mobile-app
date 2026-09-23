import 'package:flutter/foundation.dart';
import '../core/models/app_models.dart';
import '../core/repositories/school_repository.dart';

class AuthProvider extends ChangeNotifier {
  final SchoolRepository repo;
  AppUser? user;
  bool loading = false;

  AuthProvider(this.repo);

  bool get isAuthenticated => user != null;
  UserRole get role => user!.role;

  Future<void> restoreSession() async {
    final session = repo.local.getSession();
    if (session?['user'] != null) {
      user = AppUser.fromJson(Map<String, dynamic>.from(session!['user']));
    }
    notifyListeners();
  }

  Future<String?> login(String username, String password, UserRole role) async {
    loading = true;
    notifyListeners();
    try {
      user = await repo.login(username, password, role);
      return null;
    } catch (e) {
      return 'تعذر تسجيل الدخول: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await repo.logout();
    user = null;
    notifyListeners();
  }
}
