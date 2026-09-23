import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_store.dart';
import 'core/repositories/school_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/teacher_provider.dart';
import 'providers/parent_provider.dart';
import 'screens/login_screen.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/parent_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();

  final api = ApiClient();
  final repository = SchoolRepository(api, LocalStore());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(repository)..restoreSession()),
        ChangeNotifierProvider(create: (_) => TeacherProvider(repository)),
        ChangeNotifierProvider(create: (_) => ParentProvider(repository)),
      ],
      child: const SchoolApp(),
    ),
  );
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة المدارس',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorSchemeSeed: const Color(0xFF174A5B),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      ),
      locale: const Locale('ar'),
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          if (auth.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!auth.isAuthenticated) return const LoginScreen();
          return auth.role == UserRole.teacher
              ? const TeacherDashboard()
              : const ParentDashboard();
        },
      ),
    );
  }
}
