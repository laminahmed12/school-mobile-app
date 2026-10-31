import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'app_error.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'models.dart';
import 'repository.dart';
import 'supabase_config.dart';
import 'whatsapp.dart';
import 'academic.dart';
import 'student_profile.dart';
import 'reports.dart';
import 'school_setup.dart';
import 'school_branding.dart';
import 'pdf_service.dart';
import 'owner_console.dart';
import 'auth_service.dart';
import 'backup_view.dart';
import 'backup_service.dart';
import 'manager_requests.dart';
import 'trial_policy.dart';

const brandGreen = Color(0xFF155D4A);
const brandGold = Color(0xFFD7B56D);
const brandInk = Color(0xFF20312C);
const brandCanvas = Color(0xFFF3F6F3);

/// Connectivity plugins report a network link, not internet reachability.
Future<bool> _hasInternetConnection() async {
  try {
    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    final uri = Uri.parse('$base/auth/v1/health');
    final response = await http
        .get(uri, headers: {'apikey': supabasePublishableKey})
        .timeout(const Duration(seconds: 3));
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

String? _schoolTrialStatus(Map<String, dynamic>? school) {
  if (school == null) return null;
  if (school['active'] == false) return 'المدرسة موقوفة من المالك';
  if (school['licensed'] == true) return 'الترخيص الدائم مفعّل';
  final ends = schoolTrialEnd(school);
  if (ends == null) return null;
  final remaining = ends.difference(DateTime.now().toUtc());
  if (remaining <= Duration.zero) return 'انتهت الفترة التجريبية';
  final days = (remaining.inSeconds / Duration.secondsPerDay).ceil();
  final date =
      '${ends.year.toString().padLeft(4, '0')}-${ends.month.toString().padLeft(2, '0')}-${ends.day.toString().padLeft(2, '0')}';
  return 'فترة تجريبية لمدة 30 يومًا — متبقي $days يوم. تنتهي في $date';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: LaminAuthLocalStorage(),
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(LaminApp(prefs: prefs));
}

class LaminApp extends StatelessWidget {
  final SharedPreferences prefs;
  const LaminApp({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'لامين',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansArabic',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF0B3D32),
        onPrimary: Color(0xFFFFF8E8),
        secondary: Color(0xFFD7B45C),
        onSecondary: Color(0xFF172B25),
        error: Color(0xFFB5473C),
        onError: Colors.white,
        surface: Color(0xFFFFFCF5),
        onSurface: Color(0xFF20312C),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F4EB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F4EB),
        foregroundColor: Color(0xFF173B31),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF173B31),
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFCF5),
        elevation: 1,
        shadowColor: const Color(0xFF173B31).withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE8E0CE), width: 0.7),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFE8EEE6),
        indicatorColor: const Color(0xFFD0E3D6),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF0B3D32)
                : const Color(0xFF59675F),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF0B3D32)
                : const Color(0xFF59675F),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFEFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE3DCCB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE3DCCB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFF0B3D32), width: 1.8),
        ),
        labelStyle: const TextStyle(color: Color(0xFF66746B)),
        floatingLabelStyle: const TextStyle(color: Color(0xFF0B3D32)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0B3D32),
          foregroundColor: const Color(0xFFFFF8E8),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0B3D32),
          side: const BorderSide(color: Color(0xFF87988D)),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE6DFD0),
        thickness: 0.8,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF20312C),
        contentTextStyle: TextStyle(color: Color(0xFFFFFCF5)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFCF5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    home: AuthGate(prefs: prefs),
  );
}

class AuthGate extends StatefulWidget {
  final SharedPreferences prefs;
  const AuthGate({super.key, required this.prefs});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final security = DeviceSecurityService();
  bool locked = false;
  bool checking = true;
  bool mustChangePassword = false;
  bool offlineAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLock();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (db.auth.currentSession != null && mounted)
        setState(() => locked = true);
    }
  }

  Future<void> _refreshLock() async {
    final session = db.auth.currentSession;
    final enabled = await security.enabled;
    final repo = SchoolRepository(widget.prefs);
    final hasInternet = await _hasInternetConnection();
    SchoolProfile? cached;
    bool canOpenOffline = false;

    if (session != null) {
      cached = hasInternet
          ? await repo.profile().timeout(
              const Duration(seconds: 7),
              onTimeout: () => repo.cachedProfile(),
            )
          : await repo.cachedProfile();
    } else {
      // Wi-Fi/mobile connectivity does not guarantee internet access.
      final rememberedId = await const FlutterSecureStorage()
          .read(key: 'lamin.offline.user.id');
      if (rememberedId != null && rememberedId.isNotEmpty) {
        cached = await repo.cachedProfile();
        final cachedSchool = await repo.cachedSchool();
        final validTrial = schoolTrialEnd(cachedSchool)
                ?.isAfter(DateTime.now().toUtc()) ??
            false;
        final licensed = cachedSchool?['licensed'] == true;
        canOpenOffline = cached != null &&
            cached.active &&
            cached.schoolId != null &&
            cachedSchool != null &&
            cachedSchool['active'] != false &&
            (cached.role == 'owner' || cached.mustChangePassword != true) &&
            (licensed || validTrial);
      }
    }

    final activeSession = session != null || canOpenOffline;
    final forcePassword = cached?.active == true &&
        cached?.role != 'owner' &&
        cached?.mustChangePassword == true;
    if (!mounted) return;
    setState(() {
      checking = false;
      offlineAccess = canOpenOffline;
      locked = activeSession && enabled;
      mustChangePassword = forcePassword && session != null;
    });
  }

  void _unlock() {
    if (mounted) setState(() => locked = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: db.auth.onAuthStateChange,
    builder: (_, __) {
      if (db.auth.currentSession == null && !offlineAccess) return LoginPage(prefs: widget.prefs);
      if (checking || locked) return DeviceLockPage(onAuthenticated: _unlock);
      if (mustChangePassword)
        return ForcePasswordChangePage(prefs: widget.prefs);
      return HomePage(prefs: widget.prefs);
    },
  );
}

class ForcePasswordChangePage extends StatefulWidget {
  final SharedPreferences prefs;
  const ForcePasswordChangePage({super.key, required this.prefs});
  @override
  State<ForcePasswordChangePage> createState() =>
      _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool loading = false, hide = true, hideConfirm = true;
  String? error;

  Future<void> save() async {
    final p = password.text;
    if (p.length < 6 || p.length > 72 || p.contains(RegExp(r'\s'))) {
      setState(
        () => error = 'كلمة المرور يجب أن تكون من 6 إلى 72 خانة وبدون مسافات.',
      );
      return;
    }
    if (p != confirm.text) {
      setState(() => error = 'تأكيد كلمة المرور غير مطابق.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await db.functions.invoke(
        'admin-api',
        body: {'action': 'change_my_password', 'new_password': p},
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(prefs: widget.prefs)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    await db.auth.signOut();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تغيير كلمة المرور'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: loading ? null : logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: brandGreen,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'حماية الحساب',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يجب تغيير كلمة المرور المؤقتة قبل متابعة استخدام المدرسة.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: password,
                    obscureText: hide,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: loading
                            ? null
                            : () => setState(() => hide = !hide),
                        icon: Icon(
                          hide ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: hideConfirm,
                    enabled: !loading,
                    onSubmitted: (_) => save(),
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: loading
                            ? null
                            : () => setState(() => hideConfirm = !hideConfirm),
                        icon: Icon(
                          hideConfirm ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: loading ? null : save,
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        loading ? 'جارِ الحفظ...' : 'حفظ كلمة المرور',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final SharedPreferences prefs;
  const LoginPage({super.key, required this.prefs});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final school = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController();
  final auth = LaminAuthService();
  bool loading = false, hide = true, schoolLocked = false;
  bool rememberUsername = false;
  static const _rememberUsernameKey = 'lamin_remember_username';
  static const _savedUsernameKey = 'lamin_saved_username';
  String? error;
  int _ownerTaps = 0;
  DateTime? _lastOwnerTap;

  @override
  void initState() {
    super.initState();
    _loadSchool();
    _loadRememberedUsername();
  }

  static const _secureSavedUsernameKey = 'lamin.login.saved_username.v1';

  Future<void> _loadRememberedUsername() async {
    final enabled = widget.prefs.getBool(_rememberUsernameKey) ?? false;
    String? saved;
    const secureStorage = FlutterSecureStorage();
    try {
      if (enabled) {
        saved = await secureStorage.read(key: _secureSavedUsernameKey);
        if (saved == null) {
          final legacy = widget.prefs.getString(_savedUsernameKey);
          if (legacy != null && legacy.isNotEmpty) {
            await secureStorage.write(
              key: _secureSavedUsernameKey,
              value: legacy,
            );
            saved = legacy;
          }
        }
      } else {
        await secureStorage.delete(key: _secureSavedUsernameKey);
      }
      // Remove the old plaintext username once secure storage has been checked.
      await widget.prefs.remove(_savedUsernameKey);
    } catch (storageError) {
      debugPrint('Remembered username secure-storage migration failed: $storageError');
      saved = null;
      await widget.prefs.remove(_savedUsernameKey);
      await widget.prefs.setBool(_rememberUsernameKey, false);
    }
    if (!mounted) return;
    setState(() {
      rememberUsername = enabled && saved != null;
      if (saved != null) username.text = saved;
    });
  }

  Future<void> _saveUsernamePreference() async {
    const secureStorage = FlutterSecureStorage();
    try {
      if (rememberUsername) {
        await secureStorage.write(
          key: _secureSavedUsernameKey,
          value: username.text.trim(),
        );
      } else {
        await secureStorage.delete(key: _secureSavedUsernameKey);
      }
      await widget.prefs.remove(_savedUsernameKey);
      await widget.prefs.setBool(_rememberUsernameKey, rememberUsername);
    } catch (storageError) {
      debugPrint('Remembered username secure-storage write failed: $storageError');
      try {
        await secureStorage.delete(key: _secureSavedUsernameKey);
      } catch (_) {}
      await widget.prefs.remove(_savedUsernameKey);
      await widget.prefs.setBool(_rememberUsernameKey, false);
      if (mounted) setState(() => rememberUsername = false);
    }
  }

  Future<void> _loadSchool() async {
    final saved = await auth.savedSchoolCode();
    if (!mounted) return;
    if (saved != null && saved.isNotEmpty) {
      school.text = saved;
      setState(() => schoolLocked = true);
    }
  }

  Future<void> login() async {
    if (school.text.trim().isEmpty ||
        username.text.trim().isEmpty ||
        password.text.isEmpty) {
      setState(() => error = 'أدخل رمز المدرسة واسم المستخدم وكلمة المرور.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await auth.login(
        school: school.text,
        username: username.text,
        password: password.text,
      );
      if (!mounted) return;
      if (r.ok) await _saveUsernamePreference();
      setState(
        () => error = r.ok
            ? null
            : (r.trialExpired
                  ? 'المدرسة غير مفعّلة حالياً. يرجى التواصل مع مسؤول لامين لتفعيلها.'
                  : r.message),
      );
    } catch (e) {
      if (mounted)
        setState(
          () => error = friendlyError(e, fallback: 'تعذر تسجيل الدخول.'),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: brandGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'لامين',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text('لامين لإدارة وتنظيم المدارس'),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'دخول المدرسة',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: school,
                  enabled: !schoolLocked,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'رمز المدرسة',
                    prefixIcon: const Icon(Icons.domain),
                    suffixIcon: schoolLocked
                        ? IconButton(
                            onPressed: () =>
                                setState(() => schoolLocked = false),
                            icon: const Icon(Icons.edit),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: username,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: CheckboxListTile(
                    value: rememberUsername,
                    onChanged: (value) async {
                      setState(() => rememberUsername = value ?? false);
                      await _saveUsernamePreference();
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('تذكرني'),
                    subtitle: const Text('يمكنك إلغاء الخيار في أي وقت.'),
                    dense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => hide = !hide),
                      icon: Icon(
                        hide ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : login,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(loading ? 'جارِ الدخول...' : 'دخول'),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'سيتم حفظ رمز المدرسة بأمان على هذا الجهاز بعد أول دخول ناجح.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final now = DateTime.now();
                    if (_lastOwnerTap == null ||
                        now.difference(_lastOwnerTap!) >
                            const Duration(milliseconds: 900)) {
                      _ownerTaps = 1;
                    } else {
                      _ownerTaps++;
                    }
                    _lastOwnerTap = now;
                    if (_ownerTaps >= 3) {
                      _ownerTaps = 0;
                      showDialog(
                        context: context,
                        builder: (_) => _OwnerPinDialog(prefs: widget.prefs),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Adreemk', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _OwnerPinDialog extends StatefulWidget {
  final SharedPreferences prefs;
  const _OwnerPinDialog({required this.prefs});
  @override
  State<_OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<_OwnerPinDialog> {
  final code = TextEditingController();
  bool hide = true;
  bool loading = false;

  Future<void> openOwner() async {
    final pin = code.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز المالك المكوّن من 6 أرقام')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final response = await db.functions
          .invoke('owner-api', body: {'action': 'list_schools', 'pin': pin})
          .timeout(const Duration(seconds: 20));
      final data = response.data;
      if (data is Map && data['error'] != null)
        throw Exception(data['error'].toString());
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OwnerConsole(pin: pin)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: 'تعذر فتح بوابة المالك. حاول مرة أخرى.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('بوابة المالك'),
    content: TextField(
      controller: code,
      obscureText: hide,
      keyboardType: TextInputType.number,
      maxLength: 6,
      enabled: !loading,
      onSubmitted: (_) => openOwner(),
      decoration: InputDecoration(
        labelText: 'رمز المالك',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: loading ? null : () => setState(() => hide = !hide),
          icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: loading ? null : openOwner,
        child: Text(loading ? 'جارِ التحقق...' : 'فتح'),
      ),
    ],
  );
}

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;
  final int initialTab;
  const HomePage({super.key, required this.prefs, this.initialTab = 0});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final SchoolRepository repo = SchoolRepository(widget.prefs);
  late int tab = widget.initialTab;
  bool loading = true, online = true;
  SchoolProfile? profile;
  Map<String, dynamic>? schoolInfo;
  List<Student> students = [];
  List<Teacher> teachers = [];
  double payments = 0, expenses = 0;
  int pendingOperations = 0;
  int attendanceReloadVersion = 0;
  String? offlineSyncError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((_) async {
      if (!mounted) return;
      if (await _hasInternetConnection() && mounted) await refresh();
    });
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      BackupService.createLocalBackup(repo).then((_) {}, onError: (_) {});
    }
  }

  Future<void> logout() async {
    try {
      await const FlutterSecureStorage().delete(key: 'lamin.offline.user.id');
      await db.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 12));
      if (db.auth.currentSession != null) {
        throw Exception(
          'لم تُنهَ الجلسة المحلية. تحقق من الاتصال ثم أعد المحاولة.',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => AuthGate(prefs: widget.prefs)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyError(e, fallback: 'تعذر تسجيل الخروج. حاول مرة أخرى.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    String? syncFailureMessage;

    try {
      online = await _hasInternetConnection();

      if (online && db.auth.currentSession != null) {
        try {
          final result = await repo.syncPendingOfflineChanges();
          pendingOperations = result.pending;
          if (result.synced > 0) attendanceReloadVersion++;
          if (result.failedOperation != null) {
            final operation = offlineOperationLabel(result.failedOperation);
            final detail = friendlyError(
              result.error ?? 'تعذر الاتصال بالخادم.',
            );
            syncFailureMessage =
                'تعذرت مزامنة "$operation". بقيت العملية معلّقة. $detail';
            offlineSyncError = syncFailureMessage;
          } else {
            offlineSyncError = null;
          }
        } catch (error) {
          pendingOperations = await repo.pendingOfflineOperationCount();
          syncFailureMessage =
              'تعذر فحص العمليات المعلّقة: ' + friendlyError(error);
          offlineSyncError = syncFailureMessage;
        }
      } else {
        pendingOperations = await repo.pendingOfflineOperationCount();
      }

      if (!online || db.auth.currentSession == null) {
        online = false;
        profile = await repo.cachedProfile();
        schoolInfo = await repo.cachedSchool();
        students = await repo.students();
        final role = profile?.role ?? '';
        if (role == 'supervisor') {
          teachers = [];
        } else {
          teachers = await repo.teachers();
        }
        if (role == 'admin' || role == 'owner' || role == 'accountant') {
          payments = await repo.paymentsTotal();
          expenses = await repo.expensesTotal();
        } else {
          payments = 0;
          expenses = 0;
        }
      } else {
        await repo.ensureOwnerSchool();
        profile = await repo.profile();
        schoolInfo = await repo.school();

        try {
          students = await repo.students();
        } catch (_) {
          students = [];
        }

        final role = profile?.role ?? '';
        if (role == 'supervisor') {
          teachers = [];
        } else {
          try {
            teachers = await repo.teachers();
          } catch (_) {
            teachers = [];
          }
        }

        final canViewFinance =
            role == 'admin' || role == 'owner' || role == 'accountant';
        if (canViewFinance) {
          try {
            payments = await repo.paymentsTotal();
          } catch (_) {
            payments = 0;
          }
          try {
            expenses = await repo.expensesTotal();
          } catch (_) {
            expenses = 0;
          }
        } else {
          payments = 0;
          expenses = 0;
        }

        try {
          final status = await Connectivity().checkConnectivity();
          online = !status.contains(ConnectivityResult.none);
        } catch (_) {
          online = false;
        }
      }
    } catch (error) {
      debugPrint('Home refresh failed: $error');
      try {
        pendingOperations = await repo.pendingOfflineOperationCount();
      } catch (_) {}
    }

    if (mounted) setState(() => loading = false);

    if (syncFailureMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncFailureMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = profile?.role ?? '';
    final isAdmin = role == 'admin' || role == 'owner';
    final isSupervisor = role == 'supervisor';
    final isAccountant = role == 'accountant';
    final pages = <Widget>[
      DashboardView(
        profile: profile,
        schoolInfo: schoolInfo,
        students: students,
        teachers: teachers,
        payments: payments,
        expenses: expenses,
        online: online,
      ),
      if (isAdmin || isSupervisor)
        StudentsView(
          repo: repo,
          students: students,
          onChanged: refresh,
          canAdd: isAdmin || isSupervisor,
          canSetFees: isAdmin,
        ),
      if (isAdmin || isSupervisor)
        AttendanceView(
          key: ValueKey(attendanceReloadVersion),
          repo: repo,
          students: students,
        ),
      if (isAdmin || isAccountant)
        FinanceView(
          repo: repo,
          students: students,
          payments: payments,
          expenses: expenses,
          onChanged: refresh,
          canManageFees: isAdmin || isAccountant,
        ),
      if (isAdmin) BackupView(repo: repo, onChanged: refresh),
      MoreView(
        repo: repo,
        prefs: widget.prefs,
        teachers: teachers,
        students: students,
        onChanged: refresh,
        onLogout: logout,
        role: role,
      ),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'الرئيسية',
      ),
      if (isAdmin || isSupervisor)
        const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'الطلاب',
        ),
      if (isAdmin || isSupervisor)
        const NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'الحضور',
        ),
      if (isAdmin || isAccountant)
        const NavigationDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments),
          label: 'المالية',
        ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.storage_outlined),
          selectedIcon: Icon(Icons.storage),
          label: 'التخزين',
        ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz),
        selectedIcon: Icon(Icons.more_horiz),
        label: 'المزيد',
      ),
    ];
    if (tab >= pages.length) tab = 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لامين',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') await logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!online)
                  Material(
                    color: const Color(0xFFFFF0CC),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        children: const [
                          Icon(Icons.cloud_off, color: Color(0xFF795B16), size: 19),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'وضع عدم الاتصال: تعرض آخر البيانات المحفوظة، وتُحفظ التعديلات محلياً لمزامنتها عند عودة الإنترنت.',
                              style: TextStyle(color: Color(0xFF624A13), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (pendingOperations > 0)
                  Material(
                    color: const Color(0xFFE7F0EA),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 5, 8, 5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sync_problem_outlined,
                            color: brandGreen,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'عمليات معلّقة: $pendingOperations',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: brandGreen,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: loading ? null : refresh,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (offlineSyncError != null)
                  Material(
                    color: const Color(0xFFFFE8E6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              offlineSyncError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: pages[tab]),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: destinations,
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  final SchoolProfile? profile;
  final Map<String, dynamic>? schoolInfo;
  final List<Student> students;
  final List<Teacher> teachers;
  final double payments, expenses;
  final bool online;
  const DashboardView({
    super.key,
    required this.profile,
    required this.schoolInfo,
    required this.students,
    required this.teachers,
    required this.payments,
    required this.expenses,
    required this.online,
  });
  Widget stat(String title, String value, IconData icon) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final trialStatus = _schoolTrialStatus(schoolInfo);
    final trialEnded = trialStatus == 'انتهت الفترة التجريبية';
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          color: brandGreen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? '● متصل بالنظام' : '● دون اتصال',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  profile?.username.isNotEmpty == true
                      ? 'مرحباً ${profile!.username}'
                      : 'مرحباً بك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  profile?.role ?? 'مستخدم',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        if (trialStatus != null)
          Card(
            color: trialEnded
                ? const Color(0xFFFFE8E6)
                : const Color(0xFFE7F0EA),
            child: ListTile(
              leading: Icon(
                trialEnded ? Icons.warning_amber_rounded : Icons.schedule,
                color: trialEnded ? Colors.red.shade700 : brandGreen,
              ),
              title: const Text('حالة الفترة التجريبية / الترخيص'),
              subtitle: Text(trialStatus),
              isThreeLine: true,
            ),
          ),
        stat('الطلاب', '${students.length}', Icons.groups),
        if (profile?.role != 'supervisor')
          stat('المعلمون', '${teachers.length}', Icons.school),
        if (profile?.role == 'admin' ||
            profile?.role == 'owner' ||
            profile?.role == 'accountant') ...[
          stat(
            'إجمالي المدفوعات',
            '${payments.toStringAsFixed(2)} د.ل',
            Icons.account_balance_wallet,
          ),
          stat(
            'المصروفات',
            '${expenses.toStringAsFixed(2)} د.ل',
            Icons.receipt_long,
          ),
        ],
      ],
    );
  }
}

class StudentsView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  final Future<void> Function() onChanged;
  final bool canAdd;
  final bool canSetFees;
  const StudentsView({
    super.key,
    required this.repo,
    required this.students,
    required this.onChanged,
    this.canAdd = true,
    this.canSetFees = false,
  });
  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.students
        .where(
          (s) =>
              s.name.contains(q) ||
              s.className.contains(q) ||
              s.phone.contains(q),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => q = v.trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث سريع عن طالب',
                  ),
                ),
              ),
              if (widget.canAdd) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => addStudent(context),
                  icon: const Icon(Icons.person_add),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا توجد نتائج'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(s.name.isEmpty ? '?' : s.name[0]),
                        ),
                        title: Text(s.name),
                        subtitle: Text(
                          s.className +
                              (s.phone.isEmpty ? '' : ' • ${s.phone}'),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'profile') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentProfileView(
                                    repo: widget.repo,
                                    student: s,
                                  ),
                                ),
                              );
                            } else if (action == 'edit') {
                              await editStudent(s);
                            } else if (action == 'delete') {
                              await deleteStudent(s);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'profile',
                              child: Text('ملف الطالب'),
                            ),
                            if (widget.canAdd)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل بيانات الطالب'),
                              ),
                            if (widget.canAdd)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف الطالب'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> editStudent(Student student) async {
    final name = TextEditingController(text: student.name);
    final className = TextEditingController(text: student.className);
    final phone = TextEditingController(text: student.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات الطالب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم الطالب'),
              ),
              TextField(
                controller: className,
                decoration: const InputDecoration(labelText: 'الصف / الفصل'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'هاتف ولي الأمر'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true ||
        name.text.trim().length < 2 ||
        className.text.trim().isEmpty)
      return;
    try {
      await widget.repo.updateStudent(
        studentId: student.id,
        name: name.text,
        className: className.text,
        phone: phone.text,
      );
      await widget.onChanged();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تعديل بيانات الطالب.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تعديل الطالب: ${friendlyError(e, fallback: 'تعذر حفظ التغييرات.')}',
            ),
          ),
        );
    }
  }

  Future<void> deleteStudent(Student student) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الطالب'),
        content: Text(
          'سيُحذف سجل الطالب «${student.name}» إذا سمحت علاقات قاعدة البيانات بذلك. قد تمنع سجلات الحضور والدرجات والمدفوعات الحذف لحماية التاريخ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الطالب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await db.from('students').delete().eq('id', student.id);
      await widget.onChanged();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الطالب.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يُحذف الطالب؛ قد تكون له سجلات مرتبطة. احتفظ بسجلاته وأرشفه بدل الحذف. التفاصيل: ${friendlyError(e, fallback: 'عملية الحذف مرفوضة.')}',
            ),
          ),
        );
    }
  }

  Future<void> addStudent(BuildContext context) async {
    final n = TextEditingController(),
        cl = TextEditingController(),
        p = TextEditingController(),
        fee = TextEditingController();
    String term = 'الفصل الأول';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('طالب جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'اسم الطالب'),
                ),
                TextField(
                  controller: cl,
                  decoration: const InputDecoration(labelText: 'الصف / الفصل'),
                ),
                TextField(
                  controller: p,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp ولي الأمر',
                  ),
                ),
                if (widget.canSetFees) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: fee,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'قيمة الفصل الدراسي (د.ل)',
                      helperText: 'اختياري — يمكن تعديلها من المالية',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: term,
                    decoration: const InputDecoration(
                      labelText: 'الفصل الدراسي',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'الفصل الأول',
                        child: Text('الفصل الأول'),
                      ),
                      DropdownMenuItem(
                        value: 'الفصل الثاني',
                        child: Text('الفصل الثاني'),
                      ),
                      DropdownMenuItem(
                        value: 'الفصل الثالث',
                        child: Text('الفصل الثالث'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => term = v ?? 'الفصل الأول'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final amount =
                    double.tryParse(fee.text.trim().replaceAll(',', '.')) ??
                    (fee.text.trim().isEmpty ? 0 : -1);
                if (n.text.trim().length < 2 ||
                    cl.text.trim().isEmpty ||
                    amount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل اسم الطالب والصف وقيمة رسوم صحيحة.'),
                    ),
                  );
                  return;
                }
                try {
                  await widget.repo.addStudent(
                    name: n.text,
                    className: cl.text,
                    phone: p.text,
                    termFee: amount,
                    term: term,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await widget.onChanged();
                  if (context.mounted && amount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ الطالب ورسوم الفصل الدراسي.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted)
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          friendlyError(e, fallback: 'تعذر حفظ الطالب.'),
                        ),
                      ),
                    );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  const AttendanceView({
    super.key,
    required this.repo,
    required this.students,
  });
  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final Map<String, String> status = {};
  DateTime day = DateTime.now();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final requestedDay = day;
    final rows = await widget.repo.attendance(requestedDay);
    if (!mounted || requestedDay != day) return;
    final loaded = <String, String>{};
    for (final row in rows) {
      loaded[row.studentId] = row.status;
    }
    setState(() {
      status
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> mark(Student student, String value) async {
    var minutesLate = 0;
    if (value == 'late') {
      final controller = TextEditingController();
      final selectedMinutes = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('مدة التأخير — ${student.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد دقائق التأخير',
              suffixText: 'دقيقة',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed < 1) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل عدد دقائق صحيحاً أكبر من صفر.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (selectedMinutes == null) return;
      minutesLate = selectedMinutes;
    }

    final previousStatus = status[student.id];
    setState(() => status[student.id] = value);
    try {
      await widget.repo.saveAttendance(
        studentId: student.id,
        day: day,
        status: value,
        minutesLate: minutesLate,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previousStatus == null) {
          status.remove(student.id);
        } else {
          status[student.id] = previousStatus;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'تعذر حفظ سجل الحضور.'),
          ),
        ),
      );
    }
  }

  String label(String? value) {
    if (value == null) return 'غير مسجّل';
    switch (value) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      case 'excused':
        return 'معذور';
      default:
        return 'غير مسجّل';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'سجل الحضور — $date',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) {
                    setState(() {
                      day = selected;
                      status.clear();
                    });
                    await load();
                  }
                },
                icon: const Icon(Icons.calendar_today),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.students.length,
            itemBuilder: (_, index) {
              final student = widget.students[index];
              final value = status[student.id];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: ListTile(
                  title: Text(student.name),
                  subtitle: Text(label(value)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (selected) => mark(student, selected),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'present', child: Text('حاضر')),
                      PopupMenuItem(value: 'absent', child: Text('غائب')),
                      PopupMenuItem(value: 'late', child: Text('متأخر')),
                      PopupMenuItem(value: 'excused', child: Text('معذور')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FinanceView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  final double payments, expenses;
  final Future<void> Function() onChanged;
  final bool canManageFees;

  const FinanceView({
    super.key,
    required this.repo,
    required this.students,
    required this.payments,
    required this.expenses,
    required this.onChanged,
    this.canManageFees = false,
  });

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleStudents = query.isEmpty
        ? <Student>[]
        : widget.students
            .where((student) => student.name.toLowerCase().contains(query))
            .toList();

    return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Card(
                child: ListTile(
                  title: const Text('الداخل'),
                  trailing: Text('${widget.payments.toStringAsFixed(2)} د.ل'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: ListTile(
                  title: const Text('المصروف'),
                  trailing: Text('${widget.expenses.toStringAsFixed(2)} د.ل'),
                ),
              ),
            ),
          ],
        ),
      ),
      if (widget.canManageFees)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManagerRequestsView(repo: widget.repo),
                ),
              ),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text(
                'متطلبات الإدارة: المعلمون والرسوم وخطط التحصيل',
              ),
            ),
          ),
        ),
      if (widget.canManageFees)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FeeManagementView(repo: widget.repo, students: widget.students),
                ),
              ),
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('إدارة الرسوم الدراسية حسب الفصل'),
            ),
          ),
        ),
      Expanded(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'ابحث عن طالب لعرض حسابه المالي',
                  hintText: 'اكتب اسم الطالب',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          tooltip: 'مسح البحث',
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? const Center(
                      child: Text('ابحث باسم الطالب لعرض بياناته المالية.'),
                    )
                  : visibleStudents.isEmpty
                      ? const Center(child: Text('لا توجد نتائج مطابقة.'))
                      : ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: visibleStudents.length,
                itemBuilder: (_, i) {
                  final s = visibleStudents[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: widget.repo.studentFinancialSummary(s.id),
                            builder: (context, snapshot) {
                              final summary = snapshot.data;
                              final fees =
                                  (summary?['fees'] as num?)?.toDouble() ?? 0;
                              final discount =
                                  (summary?['discount'] as num?)?.toDouble() ??
                                  0;
                              final paid =
                                  (summary?['paid'] as num?)?.toDouble() ?? 0;
                              final remaining =
                                  (summary?['remaining'] as num?)?.toDouble() ??
                                  0;
                              final hasCredit = remaining < -0.009;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.school_outlined),
                                    ),
                                    title: Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${s.className} • السنة: ${summary?['academic_year'] ?? 'جارِ التحميل'}',
                                    ),
                                  ),
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting)
                                    const LinearProgressIndicator(minHeight: 2)
                                  else if (snapshot.hasError)
                                    const Text(
                                      'تعذر تحميل الرصيد. اضغط تحديثًا أو افتح كشف الحساب.',
                                      style: TextStyle(color: Colors.red),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _moneyChip('الرسوم', fees),
                                        _moneyChip('الخصم', discount),
                                        _moneyChip('المدفوع', paid),
                                        _moneyChip(
                                          hasCredit ? 'رصيد دائن' : 'المتبقي',
                                          hasCredit ? -remaining : remaining,
                                          emphasis:
                                              !hasCredit && remaining > 0.009,
                                        ),
                                      ],
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => payment(context, s),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('تسجيل دفعة'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentAccountView(
                                        repo: widget.repo,
                                        student: s,
                                        canManageFees: widget.canManageFees,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('كشف الحساب'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ],
  );
  }

  Widget _moneyChip(String label, double value, {bool emphasis = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: emphasis ? const Color(0xFFFFE6D8) : const Color(0xFFE7F0EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label: ${value.toStringAsFixed(2)} د.ل',
          style: TextStyle(
            fontSize: 12,
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w500,
            color: emphasis ? Colors.red.shade900 : null,
          ),
        ),
      );

  Future<void> payment(BuildContext context, Student s) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    List<Map<String, dynamic>> assessments = [];
    try {
      assessments = await widget.repo.studentFeeAssessments(s.id);
    } catch (_) {}
    String? selectedFeeId = assessments.isEmpty
        ? null
        : assessments.first['id']?.toString();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('دفعة — ${s.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (assessments.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: selectedFeeId,
                    decoration: const InputDecoration(
                      labelText: 'تخصيص الدفعة للفصل',
                    ),
                    items: assessments
                        .map(
                          (a) => DropdownMenuItem<String?>(
                            value: a['id']?.toString(),
                            child: Text(
                              '${a['term'] ?? 'فصل'} • ${((a['total_fee'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} د.ل',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedFeeId = v),
                  ),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستلم (د.ل)',
                  ),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة / رقم إيصال',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                  amountController.text.replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغًا أكبر من صفر.')),
                  );
                  return;
                }
                final matchingAssessments = assessments
                    .where((a) => a['id']?.toString() == selectedFeeId)
                    .toList();
                final selected = matchingAssessments.isEmpty
                    ? null
                    : matchingAssessments.first;
                Navigator.pop(ctx, {
                  'amount': amount,
                  'note': noteController.text.trim(),
                  'fee_assessment_id': selectedFeeId,
                  'term': selected?['term']?.toString() ?? 'غير محدد',
                });
              },
              child: const Text('حفظ الدفعة'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final value = (result['amount'] as num).toDouble();
    final note = result['note']?.toString() ?? '';
    try {
      await widget.repo.addPayment(
        studentId: s.id,
        amount: value,
        note: note,
        term: result['term']?.toString() ?? 'غير محدد',
        feeAssessmentId: result['fee_assessment_id']?.toString(),
      );
      try {
        await widget.onChanged();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تسجيل الدفعة، لكن تعذر تحديث العرض. أعد تحميل البيانات.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'تعذر حفظ الدفعة.')),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final makeReceipt =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تم تسجيل الدفعة'),
            content: const Text('هل تريد طباعة إيصال أو حفظه بصيغة PDF؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ليس الآن'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('إيصال PDF'),
              ),
            ],
          ),
        ) ??
        false;
    if (makeReceipt && context.mounted) {
      try {
        await LaminPdfService.printPaymentReceipt(
          repo: widget.repo,
          studentName: s.name,
          className: s.className,
          amount: value,
          note: note,
        );
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'حُفظت الدفعة، لكن تعذر إنشاء الإيصال: ${friendlyError(e)}',
              ),
            ),
          );
      }
    }
    if (s.phone.isNotEmpty && context.mounted) {
      await openWhatsApp(
        context,
        s.phone,
        'السلام عليكم، تم تسجيل دفعة للطالب ${s.name} بقيمة ${value.toStringAsFixed(2)} د.ل.',
      );
    }
  }
}

class StudentAccountView extends StatefulWidget {
  final SchoolRepository repo;
  final Student student;
  final bool canManageFees;
  const StudentAccountView({
    super.key,
    required this.repo,
    required this.student,
    required this.canManageFees,
  });
  @override
  State<StudentAccountView> createState() => _StudentAccountViewState();
}

class _StudentAccountViewState extends State<StudentAccountView> {
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  Map<String, dynamic>? parent;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      summary = await widget.repo.studentFinancialSummary(widget.student.id);
      parent = await widget.repo.parent(widget.student.id);
    } catch (e) {
      error = friendlyError(e, fallback: 'تعذر تحميل كشف الحساب.');
    }
    if (mounted) setState(() => loading = false);
  }

  double money(String key) => (summary[key] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final assessments = (summary['assessments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final payments = (summary['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final remaining = money('remaining');
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب ولي الأمر'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: loading
                ? null
                : () async {
                    try {
                      await LaminPdfService.printStudentStatement(
                        repo: widget.repo,
                        studentName: widget.student.name,
                        className: widget.student.className,
                        guardianPhone: widget.student.phone,
                        summary: summary,
                      );
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              friendlyError(
                                e,
                                fallback: 'تعذر إنشاء كشف الحساب PDF.',
                              ),
                            ),
                          ),
                        );
                    }
                  },
            tooltip: 'طباعة / PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.student.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('الصف: ${widget.student.className}'),
                          Text(
                            'ولي الأمر: ${parent?['parent_name'] ?? 'غير مسجل'}',
                          ),
                          Text(
                            'الهاتف: ${widget.student.phone.isNotEmpty ? widget.student.phone : parent?['phone'] ?? 'غير مسجل'}',
                          ),
                          Text(
                            'السنة الدراسية: ${summary['academic_year'] ?? 'غير محدد'}',
                          ),
                          const Divider(),
                          _summaryRow('إجمالي الرسوم', money('fees')),
                          _summaryRow('الخصومات', money('discount')),
                          _summaryRow('رصيد مرحّل', money('opening_balance')),
                          _summaryRow('إجمالي المدفوع', money('paid')),
                          _summaryRow(
                            remaining < 0 ? 'رصيد دائن' : 'المتبقي',
                            remaining.abs(),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.canManageFees)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeeManagementView(
                              repo: widget.repo,
                              students: [widget.student],
                              initialStudentId: widget.student.id,
                            ),
                          ),
                        );
                        await load();
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('تعديل رسوم الفصل'),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text(
                      'الرسوم حسب الفصل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (assessments.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('لا توجد رسوم مسجلة لهذه السنة الدراسية.'),
                      ),
                    )
                  else
                    ...assessments.map((fee) {
                      final total = (fee['total_fee'] as num?)?.toDouble() ?? 0;
                      final discount =
                          (fee['discount'] as num?)?.toDouble() ?? 0;
                      final relatedPaid = payments
                          .where(
                            (p) =>
                                p['fee_assessment_id']?.toString() ==
                                fee['id']?.toString(),
                          )
                          .fold<double>(
                            0,
                            (sum, p) =>
                                sum + ((p['amount'] as num?)?.toDouble() ?? 0),
                          );
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(
                            fee['term']?.toString() ?? 'الفصل الدراسي',
                          ),
                          subtitle: Text(
                            'الرسوم: ${total.toStringAsFixed(2)} • الخصم: ${discount.toStringAsFixed(2)} • المدفوع المخصص: ${relatedPaid.toStringAsFixed(2)} د.ل',
                          ),
                          trailing: Text(
                            '${(total - discount - relatedPaid).toStringAsFixed(2)} د.ل',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      );
                    }),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
                    child: Text(
                      'سجل الدفعات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (payments.isEmpty)
                    const Card(
                      child: ListTile(title: Text('لا توجد دفعات مسجلة.')),
                    )
                  else
                    ...payments.map(
                      (p) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(
                            '${((p['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} د.ل',
                          ),
                          subtitle: Text(
                            '${p['payment_date'] ?? p['created_at']?.toString().split('T').first ?? ''} • ${p['term'] ?? 'غير محدد'}${(p['note']?.toString().isNotEmpty ?? false) ? ' • ${p['note']}' : ''}',
                          ),
                          trailing: widget.canManageFees
                              ? const Tooltip(
                                  message:
                                      'سجل مالي ثابت؛ لا يُعدّل أو يُحذف مباشرة.',
                                  child: Icon(
                                    Icons.verified_outlined,
                                    color: Colors.green,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} د.ل',
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class FeeManagementView extends StatefulWidget {
  final SchoolRepository repo;
  final List<Student> students;
  final String? initialStudentId;
  const FeeManagementView({
    super.key,
    required this.repo,
    required this.students,
    this.initialStudentId,
  });
  @override
  State<FeeManagementView> createState() => _FeeManagementViewState();
}

class _FeeManagementViewState extends State<FeeManagementView> {
  final feeController = TextEditingController();
  final studentSearchController = TextEditingController();
  final discountController = TextEditingController(text: '0');
  final noteController = TextEditingController();
  List<Map<String, dynamic>> years = [];
  String? studentId;
  String? yearId;
  String term = 'الفصل الأول';
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    feeController.dispose();
    studentSearchController.dispose();
    discountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      years = await widget.repo.academicYears();
      studentId = widget.initialStudentId;
      if (studentId != null) {
        final selected = widget.students
            .where((student) => student.id == studentId)
            .toList();
        if (selected.isNotEmpty) {
          studentSearchController.text = selected.first.name;
        }
      }
      final activeYears = years.where((y) => y['active'] == true).toList();
      final active = activeYears.isEmpty ? null : activeYears.first;
      yearId = active?['id']?.toString();
      await prefill();
    } catch (e) {
      error = friendlyError(e, fallback: 'تعذر تحميل الرسوم.');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> selectStudent(Student student) async {
    setState(() {
      studentId = student.id;
      studentSearchController.text = student.name;
      error = null;
    });
    await prefill();
    if (mounted) setState(() {});
  }

  Future<void> prefill() async {
    if (studentId == null) return;
    try {
      var query = db
          .from('student_fee_assessments')
          .select(
            'id,total_fee,discount,note,academic_year_id,academic_year_label,term',
          )
          .eq('student_id', studentId!)
          .eq('term', term);
      var row = yearId == null
          ? await query.isFilter('academic_year_id', null).maybeSingle()
          : await query.eq('academic_year_id', yearId!).maybeSingle();
      if (row == null && yearId != null) {
        row = await db
            .from('student_fee_assessments')
            .select(
              'id,total_fee,discount,note,academic_year_id,academic_year_label,term',
            )
            .eq('student_id', studentId!)
            .eq('term', term)
            .isFilter('academic_year_id', null)
            .maybeSingle();
      }
      feeController.text = row?['total_fee']?.toString() ?? '';
      discountController.text = row?['discount']?.toString() ?? '0';
      noteController.text = row?['note']?.toString() ?? '';
    } catch (_) {
      feeController.clear();
      discountController.text = '0';
      noteController.clear();
    }
  }

  Future<void> save() async {
    final fee = double.tryParse(feeController.text.replaceAll(',', '.'));
    final discount =
        double.tryParse(discountController.text.replaceAll(',', '.')) ?? 0;
    if (studentId == null ||
        fee == null ||
        fee < 0 ||
        discount < 0 ||
        discount > fee) {
      setState(
        () => error =
            'اختر الطالب وأدخل رسومًا صحيحة، ويجب ألا يتجاوز الخصم الرسوم.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final selectedYears = years
          .where((y) => y['id']?.toString() == yearId)
          .toList();
      final year = selectedYears.isEmpty ? null : selectedYears.first;
      await widget.repo.saveStudentFeeAssessment(
        studentId: studentId!,
        term: term,
        totalFee: fee,
        discount: discount,
        academicYearId: yearId,
        academicYearLabel: year?['name']?.toString() ?? 'غير محدد',
        note: noteController.text,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ رسوم الفصل الدراسي.')),
        );
      await prefill();
    } catch (e) {
      error = friendlyError(e, fallback: 'تعذر حفظ رسوم الفصل.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الرسوم الدراسية')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'تحديد الرسوم حسب السنة والفصل',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: studentSearchController,
                        enabled: !saving,
                        onChanged: (_) => setState(() {
                          studentId = null;
                          feeController.clear();
                          discountController.text = '0';
                          noteController.clear();
                          error = null;
                        }),
                        decoration: InputDecoration(
                          labelText: 'ابحث عن الطالب بالاسم',
                          hintText: 'اكتب اسم الطالب لعرض نتيجة البحث',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: studentSearchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح البحث',
                                  onPressed: saving
                                      ? null
                                      : () {
                                          setState(() {
                                            studentId = null;
                                            studentSearchController.clear();
                                            feeController.clear();
                                            discountController.text = '0';
                                            noteController.clear();
                                          });
                                        },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                      if (studentId == null &&
                          studentSearchController.text.trim().isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('أدخل اسم الطالب للعثور عليه.'),
                        ),
                      if (studentId == null &&
                          studentSearchController.text.trim().isNotEmpty)
                        ...widget.students
                            .where(
                              (student) => student.name.toLowerCase().contains(
                                studentSearchController.text.trim().toLowerCase(),
                              ),
                            )
                            .take(12)
                            .map(
                              (student) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.person_outline),
                                title: Text(student.name),
                                subtitle: Text(student.className),
                                onTap: saving ? null : () => selectStudent(student),
                              ),
                            ),
                      if (studentId != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_pin_circle_outlined),
                          title: Text(studentSearchController.text),
                          subtitle: const Text('الطالب المحدد'),
                          trailing: IconButton(
                            tooltip: 'تغيير الطالب',
                            onPressed: saving
                                ? null
                                : () {
                                    setState(() {
                                      studentId = null;
                                      studentSearchController.clear();
                                      feeController.clear();
                                      discountController.text = '0';
                                      noteController.clear();
                                    });
                                  },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: yearId,
                        decoration: const InputDecoration(
                          labelText: 'السنة الدراسية',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('غير محددة / لم تُنشأ سنة بعد'),
                          ),
                          ...years.map(
                            (y) => DropdownMenuItem<String?>(
                              value: y['id']?.toString(),
                              child: Text(
                                '${y['name']}${y['active'] == true ? ' (نشطة)' : ''}',
                              ),
                            ),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) async {
                                setState(() => yearId = v);
                                await prefill();
                                if (mounted) setState(() {});
                              },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: term,
                        decoration: const InputDecoration(
                          labelText: 'الفصل الدراسي',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'الفصل الأول',
                            child: Text('الفصل الأول'),
                          ),
                          DropdownMenuItem(
                            value: 'الفصل الثاني',
                            child: Text('الفصل الثاني'),
                          ),
                          DropdownMenuItem(
                            value: 'الفصل الثالث',
                            child: Text('الفصل الثالث'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) async {
                                setState(() => term = v ?? 'الفصل الأول');
                                await prefill();
                                if (mounted) setState(() {});
                              },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: feeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'قيمة الفصل الدراسي (د.ل)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الخصم (د.ل)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'ملاحظة'),
                      ),
                      if (years.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'لم تُنشأ سنة دراسية بعد. يمكنك حفظ الرسوم تحت "غير محدد"، أو إنشاء سنة من إعداد المدرسة لربط الحساب بها.',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: saving ? null : save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'جارِ الحفظ...' : 'حفظ الرسوم'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class UserManagementView extends StatefulWidget {
  final SchoolRepository repo;
  const UserManagementView({super.key, required this.repo});
  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  List<Map<String, dynamic>> users = [];
  bool loading = true, saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      users = await widget.repo.schoolUsers();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _adminCall(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final response = await db.functions
        .invoke('admin-api', body: {'action': action, ...fields})
        .timeout(const Duration(seconds: 20));
    final data = response.data;
    if (data is Map && data['error'] != null)
      throw Exception(data['error'].toString());
    if (data is! Map || data['ok'] != true)
      throw Exception('لم يؤكد الخادم نجاح العملية.');
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير المدرسة';
      case 'supervisor':
        return 'مشرف';
      case 'accountant':
        return 'محاسب';
      case 'owner':
        return 'مالك النظام';
      default:
        return role ?? 'غير محدد';
    }
  }

  Future<void> editUser({Map<String, dynamic>? user}) async {
    final username = TextEditingController(
      text: user?['username']?.toString() ?? '',
    );
    final password = TextEditingController();
    String role = user?['role']?.toString() == 'admin'
        ? 'admin'
        : (user?['role']?.toString() == 'accountant'
              ? 'accountant'
              : 'supervisor');
    final formKey = GlobalKey<FormState>();
    final isNew = user == null;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(isNew ? 'إضافة مستخدم' : 'تعديل المستخدم'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: username,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                        ),
                        validator: (v) =>
                            v == null ||
                                v.trim().length < 2 ||
                                v.trim().length > 40
                            ? 'الاسم من 2 إلى 40 حرفاً'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'الدور والصلاحيات',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('مدير المدرسة'),
                          ),
                          DropdownMenuItem(
                            value: 'supervisor',
                            child: Text('مشرف'),
                          ),
                          DropdownMenuItem(
                            value: 'accountant',
                            child: Text('محاسب'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => role = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isNew
                              ? 'كلمة المرور المؤقتة'
                              : 'كلمة مرور جديدة (اختياري)',
                          helperText: isNew
                              ? 'سيُطلب منه تغييرها عند أول دخول.'
                              : 'اتركها فارغة دون تغيير.',
                        ),
                        validator: (v) {
                          if (isNew &&
                              (v == null ||
                                  v.length < 6 ||
                                  v.length > 72 ||
                                  v.contains(RegExp(r'\s'))))
                            return 'كلمة المرور 6 خانات على الأقل وبدون مسافات';
                          if (v != null &&
                              v.isNotEmpty &&
                              (v.length < 6 ||
                                  v.length > 72 ||
                                  v.contains(RegExp(r'\s'))))
                            return 'كلمة المرور 6 خانات على الأقل وبدون مسافات';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (mounted) setState(() => saving = true);
                          try {
                            if (isNew) {
                              await _adminCall('create_user', {
                                'username': username.text.trim(),
                                'password': password.text,
                                'role': role,
                              });
                            } else {
                              await _adminCall('update_user', {
                                'user_id': user['user_id'],
                                'username': username.text.trim(),
                                'role': role,
                                if (password.text.isNotEmpty)
                                  'password': password.text,
                              });
                            }
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext, true);
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    friendlyError(
                                      e,
                                      fallback: 'تعذر حفظ المستخدم.',
                                    ),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(
                    saving ? 'جارِ الحفظ...' : (isNew ? 'إضافة' : 'حفظ'),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
    username.dispose();
    password.dispose();
    if (confirmed) {
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew
                  ? 'تم إنشاء المستخدم؛ يجب تغيير كلمة المرور عند أول دخول.'
                  : 'تم تحديث بيانات المستخدم.',
            ),
          ),
        );
    }
  }

  Future<void> toggleActive(Map<String, dynamic> user) async {
    final active = user['active'] == true;
    final name = user['username']?.toString() ?? 'المستخدم';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(active ? 'إيقاف الحساب' : 'تفعيل الحساب'),
            content: Text(
              active
                  ? 'سيُمنع ' + name + ' من الدخول مع الاحتفاظ بسجلاته.'
                  : 'سيُسمح لـ ' + name + ' بالدخول مجدداً.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(active ? 'إيقاف' : 'تفعيل'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _adminCall('update_user', {
        'user_id': user['user_id'],
        'active': !active,
      });
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(active ? 'تم إيقاف الحساب.' : 'تم تفعيل الحساب.'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final name = user['username']?.toString() ?? 'المستخدم';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('حذف المستخدم'),
            content: Text('هل تريد حذف حساب ' + name + ' نهائياً؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _adminCall('delete_user', {'user_id': user['user_id']});
      await load();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف المستخدم.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }

  Future<void> oneDrive(Map<String, dynamic> u) async {
    final id = u['user_id']?.toString() ?? '';
    final name = u['username']?.toString() ?? '';
    final granted = u['onedrive_access_granted'] == true;
    final email = TextEditingController(
      text: u['microsoft_email']?.toString() ?? '',
    );
    final token = TextEditingController(),
        drive = TextEditingController(),
        folder = TextEditingController();
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(
              granted ? 'إلغاء صلاحية OneDrive' : 'منح صلاحية OneDrive',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('المستخدم: ' + name),
                  const SizedBox(height: 10),
                  const Text(
                    'هذه صلاحية إدارية منفصلة عن صلاحيات لامين، لربط المستخدم بمجلد OneDrive محدد. منحها لا يرفع النسخ الاحتياطية تلقائيًا. لا تدخل كلمة مرور Microsoft هنا؛ يلزم رمز وصول ومعرّفات صحيحة من مسؤول الربط.',
                  ),
                  if (!granted) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'بريد Microsoft / OneDrive',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: token,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'رمز وصول Microsoft (Access Token)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: drive,
                    decoration: const InputDecoration(
                      labelText: 'معرّف مساحة OneDrive (Drive ID)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: folder,
                    decoration: const InputDecoration(
                      labelText: 'معرّف مجلد المدرسة (Folder ID)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(granted ? 'إلغاء الصلاحية' : 'منح الصلاحية'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      if (token.text.trim().isEmpty)
        throw Exception('أدخل رمز وصول Microsoft الصالح، وليس كلمة المرور.');
      if (drive.text.trim().isEmpty)
        throw Exception('أدخل معرّف مساحة OneDrive.');
      if (folder.text.trim().isEmpty)
        throw Exception('أدخل معرّف مجلد المدرسة.');
      if (granted) {
        await widget.repo.revokeOneDriveAccess(
          id,
          microsoftAccessToken: token.text.trim(),
          driveId: drive.text.trim(),
          folderItemId: folder.text.trim(),
        );
      } else {
        if (email.text.trim().isEmpty) throw Exception('أدخل بريد Microsoft');
        await widget.repo.grantOneDriveAccess(
          id,
          microsoftEmail: email.text,
          microsoftAccessToken: token.text.trim(),
          driveId: drive.text.trim(),
          folderItemId: folder.text.trim(),
        );
      }
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted ? 'تم إلغاء صلاحية OneDrive.' : 'تم منح صلاحية OneDrive.',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مستخدمو المدرسة'),
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: saving ? null : () => editUser(),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('إضافة مستخدم'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.security),
                  title: Text('الأدوار والصلاحيات'),
                  subtitle: Text(
                    'مدير المدرسة لإدارة الحسابات، المشرف للمتابعة، والمحاسب للشؤون المالية. صلاحيات OneDrive تدار بشكل منفصل.',
                  ),
                ),
              ),
              ...users.map((u) {
                final role = _roleLabel(u['role']?.toString());
                final granted = u['onedrive_access_granted'] == true;
                final isOwner = u['role'] == 'owner';
                final active = u['active'] == true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        u['role'] == 'accountant'
                            ? Icons.calculate
                            : u['role'] == 'supervisor'
                            ? Icons.supervisor_account
                            : Icons.admin_panel_settings,
                      ),
                    ),
                    title: Text(u['username']?.toString() ?? '—'),
                    subtitle: Text(
                      role +
                          ' • ' +
                          (active ? 'نشط' : 'موقوف') +
                          '\nOneDrive: ' +
                          (granted ? 'مصرّح' : 'غير مصرح'),
                    ),
                    isThreeLine: true,
                    trailing: isOwner
                        ? const Icon(Icons.shield)
                        : PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') editUser(user: u);
                              if (value == 'active') toggleActive(u);
                              if (value == 'delete') deleteUser(u);
                              if (value == 'drive') oneDrive(u);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل البيانات والدور'),
                              ),
                              PopupMenuItem(
                                value: 'active',
                                child: Text(
                                  active ? 'إيقاف الحساب' : 'تفعيل الحساب',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'drive',
                                child: Text('إدارة صلاحية OneDrive'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف المستخدم'),
                              ),
                            ],
                          ),
                  ),
                );
              }),
            ],
          ),
  );
}

class TeacherManagementView extends StatefulWidget {
  final SchoolRepository repo;
  final Future<void> Function() onChanged;
  const TeacherManagementView({
    super.key,
    required this.repo,
    required this.onChanged,
  });
  @override
  State<TeacherManagementView> createState() => _TeacherManagementViewState();
}

class _TeacherManagementViewState extends State<TeacherManagementView> {
  List<Teacher> teachers = [];
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      teachers = await widget.repo.teachers();
    } catch (e) {
      error = friendlyError(e, fallback: 'تعذر تحميل قائمة المعلمين.');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> editTeacher(Teacher teacher) async {
    final name = TextEditingController(text: teacher.name);
    final subject = TextEditingController(text: teacher.subject);
    final phone = TextEditingController(text: teacher.phone);
    final current = await db
        .from('teachers')
        .select('salary')
        .eq('id', teacher.id)
        .maybeSingle();
    final salary = TextEditingController(
      text: current?['salary']?.toString() ?? '0',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات المعلم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم المعلم'),
              ),
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'المادة / التخصص'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
              TextField(
                controller: salary,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الراتب الشهري (د.ل)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final monthly = double.tryParse(salary.text.replaceAll(',', '.'));
    if (ok != true ||
        name.text.trim().length < 2 ||
        subject.text.trim().isEmpty ||
        monthly == null ||
        monthly < 0)
      return;
    try {
      setState(() => saving = true);
      await db
          .from('teachers')
          .update({
            'name': name.text.trim(),
            'subject': subject.text.trim(),
            'phone': phone.text.replaceAll(RegExp(r'[^0-9+]'), ''),
            'salary': monthly,
          })
          .eq('id', teacher.id);
      await load();
      await widget.onChanged();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تعديل المعلم: ${friendlyError(e, fallback: 'تعذر حفظ التغييرات.')}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteTeacher(Teacher teacher) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف المعلم'),
        content: Text(
          'سيُحذف سجل «${teacher.name}» إذا لم تكن له سجلات رواتب أو حضور مرتبطة. ستمنع قاعدة البيانات الحذف عند وجود علاقات تحمي السجل التاريخي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف المعلم'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      setState(() => saving = true);
      await db.from('teachers').delete().eq('id', teacher.id);
      await load();
      await widget.onChanged();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يُحذف المعلم؛ قد تكون له سجلات رواتب أو سنوات دراسية. أرشفه للحفاظ على التاريخ. التفاصيل: ${friendlyError(e, fallback: 'عملية الحذف مرفوضة.')}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> addTeacher() async {
    final name = TextEditingController();
    final subject = TextEditingController();
    final phone = TextEditingController();
    final salary = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة معلم جديد'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'اسم المعلم'),
                  validator: (v) => v == null || v.trim().length < 2
                      ? 'أدخل اسم المعلم'
                      : null,
                ),
                TextFormField(
                  controller: subject,
                  decoration: const InputDecoration(
                    labelText: 'المادة / التخصص',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'أدخل المادة أو التخصص'
                      : null,
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                  ),
                  validator: (v) {
                    final p = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    return p.isNotEmpty && (p.length < 8 || p.length > 15)
                        ? 'رقم الهاتف من 8 إلى 15 رقمًا'
                        : null;
                  },
                ),
                TextFormField(
                  controller: salary,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الراتب الشهري (د.ل)',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    return n == null || n < 0 ? 'أدخل راتبًا صحيحًا' : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    final monthly = double.parse(
                      salary.text.replaceAll(',', '.'),
                    );
                    Navigator.pop(ctx, true);
                    try {
                      if (mounted) setState(() => saving = true);
                      await widget.repo.addTeacher(
                        name: name.text,
                        subject: subject.text,
                        phone: phone.text,
                        salary: monthly,
                      );
                      await load();
                      await widget.onChanged();
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمت إضافة المعلم بنجاح.'),
                          ),
                        );
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              friendlyError(e, fallback: 'تعذرت إضافة المعلم.'),
                            ),
                          ),
                        );
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: const Text('حفظ المعلم'),
          ),
        ],
      ),
    );
    if (saved == null) return;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('المعلمون'),
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          tooltip: 'تحديث',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: saving ? null : addTeacher,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('إضافة معلم'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42),
                  const SizedBox(height: 10),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          )
        : teachers.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 56, color: brandGreen),
                  SizedBox(height: 12),
                  Text(
                    'لا يوجد معلمون مسجلون بعد.',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'اضغط «إضافة معلم» لتسجيل أول معلم وربط راتبه بالمالية.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              children: teachers
                  .map(
                    (t) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.school_outlined),
                        ),
                        title: Text(t.name),
                        subtitle: Text(
                          '${t.subject}${t.phone.isEmpty ? '' : ' • ${t.phone}'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') editTeacher(t);
                            if (action == 'delete') deleteTeacher(t);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل بيانات المعلم'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف المعلم'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

class MoreView extends StatelessWidget {
  final SchoolRepository repo;
  final SharedPreferences prefs;
  final List<Teacher> teachers;
  final List<Student> students;
  final Future<void> Function() onChanged;
  final Future<void> Function() onLogout;
  final String role;
  const MoreView({
    super.key,
    required this.repo,
    required this.prefs,
    required this.teachers,
    required this.students,
    required this.onChanged,
    required this.onLogout,
    required this.role,
  });
  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin' || role == 'owner';
    final isSupervisor = role == 'supervisor';
    final isAccountant = role == 'accountant';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (isAdmin)
          Card(
            child: ListTile(
              leading: const Icon(Icons.school),
              title: const Text('المعلمون'),
              subtitle: Text('${teachers.length} معلم — إضافة وإدارة المعلمين'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TeacherManagementView(repo: repo, onChanged: onChanged),
                ),
              ),
            ),
          ),
        if (isAdmin || isAccountant)
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('مصروف جديد'),
              subtitle: const Text('تسجيل مصروف المدرسة'),
              onTap: () => expense(context),
            ),
          ),
        if (isAdmin || isAccountant)
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('المرتبات والسلف'),
              subtitle: const Text(
                'رواتب المعلمين والموظفين وتسجيل المرتبات والسلف',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PayrollView(
                    repo: repo,
                    onChanged: onChanged,
                    canManagePayees: isAdmin,
                  ),
                ),
              ),
            ),
          ),
        if (isAdmin || isAccountant)
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('التقارير اليومية'),
              subtitle: const Text('حضور وغياب ومدفوعات ومصروفات'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportsView(repo: repo)),
              ),
            ),
          ),
        if (isAdmin || isSupervisor)
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('الدرجات والنتائج'),
              subtitle: const Text('إدخال الدرجات وإرسال النتيجة عبر WhatsApp'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AcademicView(repo: repo, students: students),
                ),
              ),
            ),
          ),
        if (isAdmin)
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('إعداد المدرسة'),
              subtitle: const Text('السنوات والصفوف والمواد'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SchoolSetupView(repo: repo)),
              ),
            ),
          ),
        if (isAdmin)
          Card(
            child: ListTile(
              leading: const Icon(Icons.branding_watermark_outlined),
              title: const Text('شعار المدرسة للطباعة'),
              subtitle: const Text(
                'رفع الشعار ليظهر على التقارير وإيصالات PDF',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SchoolBrandingView(repo: repo),
                ),
              ),
            ),
          ),
        if (isAdmin)
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('مستخدمو المدرسة'),
              subtitle: const Text('إدارة المسؤولين والمشرفين والمحاسبين'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserManagementView(repo: repo),
                ),
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('الدخول بالبصمة'),
            subtitle: const Text(
              'من المزيد ← الدخول بالبصمة. فعّل بصمة الهاتف أولاً من إعدادات الجهاز.',
            ),
            onTap: () async {
              final service = DeviceSecurityService();
              final enabled = await service.enabled;
              if (!context.mounted) return;
              if (enabled) {
                await service.disable();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تعطيل الدخول بالبصمة.')),
                  );
              } else {
                final ok = await service.enable();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'تم تفعيل الدخول بالبصمة.'
                          : 'لم يتم التفعيل. تأكد من إعداد بصمة على الجهاز.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            subtitle: const Text(
              'إنهاء جلسة هذا الحساب والعودة إلى شاشة الدخول',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: onLogout,
          ),
        ),
      ],
    );
  }

  Future<void> expense(BuildContext context) async {
    final t = TextEditingController(),
        a = TextEditingController(),
        cat = TextEditingController(text: 'عام');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مصروف جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: t,
              decoration: const InputDecoration(labelText: 'البيان'),
            ),
            TextField(
              controller: cat,
              decoration: const InputDecoration(labelText: 'التصنيف'),
            ),
            TextField(
              controller: a,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'المبلغ د.ل'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(a.text.replaceAll(',', '.'));
              if (t.text.trim().isEmpty || v == null || v <= 0) return;
              try {
                await repo.addExpense(
                  title: t.text,
                  amount: v,
                  category: cat.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await onChanged();
              } catch (_) {
                if (ctx.mounted)
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('تعذر حفظ المصروف')),
                  );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class PayrollView extends StatefulWidget {
  final SchoolRepository repo;
  final Future<void> Function() onChanged;
  final bool canManagePayees;
  const PayrollView({
    super.key,
    required this.repo,
    required this.onChanged,
    required this.canManagePayees,
  });

  @override
  State<PayrollView> createState() => _PayrollViewState();
}

class _PayrollViewState extends State<PayrollView> {
  bool loading = true, saving = false;
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> staff = [];
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final values = await Future.wait([
        db
            .from('teachers')
            .select('id,name,subject,phone,salary')
            .order('name'),
        widget.repo.staffMembers(),
        widget.repo.payrollTransactions(),
      ]);
      teachers = (values[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      staff = (values[1] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      transactions = (values[2] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyError(e, fallback: 'تعذر تحميل بيانات المرتبات.'),
            ),
          ),
        );
    }
    if (mounted) setState(() => loading = false);
  }

  double _amount(Map<String, dynamic> row) =>
      (row['amount'] as num?)?.toDouble() ?? 0;
  double _salary(Map<String, dynamic> row) =>
      (row['salary'] as num?)?.toDouble() ?? 0;
  bool _thisMonth(Map<String, dynamic> row) {
    final value = row['payment_date']?.toString() ?? '';
    final now = DateTime.now();
    return value.length >= 7 &&
        value.substring(0, 7) ==
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final monthTransactions = transactions.where(_thisMonth).toList();
    final salaryTotal = monthTransactions
        .where((e) => e['transaction_type'] == 'salary')
        .fold<double>(0, (sum, e) => sum + _amount(e));
    final advanceTotal = monthTransactions
        .where((e) => e['transaction_type'] == 'advance')
        .fold<double>(0, (sum, e) => sum + _amount(e));
    return Scaffold(
      appBar: AppBar(
        title: const Text('المرتبات والسلف'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ملخص شهر ${DateTime.now().month}/${DateTime.now().year}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _summary(
                                  'المرتبات المصروفة',
                                  salaryTotal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: _summary('السلف', advanceTotal)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'تُحتسب المرتبات والسلف ضمن إجمالي مصروفات المدرسة.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.canManagePayees)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add_alt_1),
                        title: const Text('إضافة موظف'),
                        subtitle: const Text(
                          'إضافة موظف غير مدرج ضمن المعلمين',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: addStaff,
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Text(
                      'المعلمون المسجلون',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (teachers.isEmpty)
                    const Card(
                      child: ListTile(title: Text('لا يوجد معلمون مسجلون.')),
                    ),
                  ...teachers.map(
                    (person) => _payeeCard(person, isTeacher: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text(
                      'الموظفون',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (staff.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text(
                          'لا يوجد موظفون مسجلون. أضف موظفًا من زر الإضافة.',
                        ),
                      ),
                    ),
                  ...staff
                      .where((p) => p['active'] != false)
                      .map((person) => _payeeCard(person, isTeacher: false)),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 18, 4, 4),
                    child: Text(
                      'سجل المرتبات والسلف',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (transactions.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('لا توجد عمليات مسجلة حتى الآن.'),
                      ),
                    )
                  else
                    ...transactions.map(_transactionCard),
                ],
              ),
            ),
    );
  }

  Widget _summary(String label, double value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F0EA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          '${value.toStringAsFixed(2)} د.ل',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _payeeCard(Map<String, dynamic> person, {required bool isTeacher}) {
    final salary = _salary(person);
    final name = person['name']?.toString() ?? '—';
    final payeeType = isTeacher ? 'teacher' : 'staff';
    final payeeId = person['id']?.toString() ?? '';
    final monthRows = transactions
        .where(
          (tx) =>
              tx['payee_type']?.toString() == payeeType &&
              tx['payee_id']?.toString() == payeeId &&
              _thisMonth(tx),
        )
        .toList();
    final salaryPaid = monthRows
        .where((tx) => tx['transaction_type'] == 'salary')
        .fold<double>(0, (sum, tx) => sum + _amount(tx));
    final advancePaid = monthRows
        .where((tx) => tx['transaction_type'] == 'advance')
        .fold<double>(0, (sum, tx) => sum + _amount(tx));
    final remaining = salary - salaryPaid - advancePaid;
    final subtitle = isTeacher
        ? (person['subject']?.toString().isNotEmpty == true
              ? person['subject'].toString()
              : 'معلم')
        : (person['role']?.toString() ?? 'موظف');
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Icon(
                  isTeacher ? Icons.school_outlined : Icons.badge_outlined,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '$subtitle • الراتب الشهري: ${salary.toStringAsFixed(2)} د.ل\\n'
                'المصروف راتبًا: ${salaryPaid.toStringAsFixed(2)} • السلف: ${advancePaid.toStringAsFixed(2)} د.ل\\n'
                '${remaining < -0.009 ? 'زيادة مصروفة' : 'المتبقي من الراتب'}: ${remaining.abs().toStringAsFixed(2)} د.ل',
              ),
              trailing: widget.canManagePayees
                  ? IconButton(
                      tooltip: 'تعديل بيانات',
                      onPressed: () => editPayee(person, isTeacher: isTeacher),
                      icon: const Icon(Icons.edit_outlined),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: saving
                          ? null
                          : () => recordTransaction(
                              person,
                              isTeacher: isTeacher,
                              type: 'salary',
                            ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('صرف راتب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => recordTransaction(
                              person,
                              isTeacher: isTeacher,
                              type: 'advance',
                            ),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('سلفة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> tx) {
    final type = tx['payee_type']?.toString() ?? '';
    final id = tx['payee_id']?.toString() ?? '';
    final source = type == 'teacher' ? teachers : staff;
    Map<String, dynamic>? person;
    for (final p in source) {
      if (p['id']?.toString() == id) {
        person = p;
        break;
      }
    }
    final isAdvance = tx['transaction_type'] == 'advance';
    final date = tx['payment_date']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isAdvance
                ? Icons.account_balance_wallet_outlined
                : Icons.payments_outlined,
          ),
        ),
        title: Text(
          '${person?['name'] ?? 'مستفيد غير موجود'} — ${isAdvance ? 'سلفة' : 'راتب'}',
        ),
        subtitle: Text(
          '$date${(tx['note']?.toString().trim().isNotEmpty ?? false) ? ' • ${tx['note']}' : ''}',
        ),
        trailing: Text(
          '${_amount(tx).toStringAsFixed(2)} د.ل',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> editPayee(
    Map<String, dynamic> person, {
    required bool isTeacher,
  }) async {
    final name = TextEditingController(text: person['name']?.toString() ?? '');
    final detail = TextEditingController(
      text: (isTeacher ? person['subject'] : person['role'])?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: person['phone']?.toString() ?? '',
    );
    final salary = TextEditingController(
      text: _salary(person).toStringAsFixed(2),
    );
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل ${isTeacher ? 'بيانات المعلم' : 'بيانات الموظف'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: detail,
                decoration: InputDecoration(
                  labelText: isTeacher ? 'المادة / التخصص' : 'الوظيفة',
                ),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
              TextField(
                controller: salary,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الراتب الشهري (د.ل)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                salary.text.trim().replaceAll(',', '.'),
              );
              if (name.text.trim().length < 2 ||
                  detail.text.trim().isEmpty ||
                  amount == null ||
                  amount < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('تحقق من الاسم والمادة أو الوظيفة والراتب.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, {
                'name': name.text.trim(),
                'detail': detail.text.trim(),
                'phone': phone.text.trim(),
                'salary': amount,
              });
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      if (isTeacher) {
        await widget.repo.updateTeacher(
          teacherId: person['id'].toString(),
          name: value['name'] as String,
          subject: value['detail'] as String,
          phone: value['phone'] as String,
          salary: value['salary'] as double,
        );
      } else {
        await widget.repo.updateStaffMember(
          staffId: person['id'].toString(),
          name: value['name'] as String,
          role: value['detail'] as String,
          phone: value['phone'] as String,
          salary: value['salary'] as double,
        );
      }
      await load();
      await widget.onChanged();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث البيانات بنجاح.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'تعذر تحديث البيانات.')),
          ),
        );
    }
  }

  Future<void> editSalary(
    Map<String, dynamic> person, {
    required bool isTeacher,
  }) async {
    final controller = TextEditingController(
      text: _salary(person).toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('راتب ${person['name'] ?? ''}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'الراتب الشهري (د.ل)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (amount == null || amount < 0) return;
              Navigator.pop(ctx, amount);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      if (isTeacher) {
        await widget.repo.setTeacherSalary(person['id'].toString(), value);
      } else {
        await widget.repo.setStaffSalary(person['id'].toString(), value);
      }
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'تعذر تحديث الراتب.')),
          ),
        );
    }
  }

  Future<void> addStaff() async {
    final name = TextEditingController();
    final role = TextEditingController(text: 'موظف');
    final phone = TextEditingController();
    final salary = TextEditingController(text: '0');
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة موظف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم الموظف'),
              ),
              TextField(
                controller: role,
                decoration: const InputDecoration(labelText: 'الوظيفة'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                ),
              ),
              TextField(
                controller: salary,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الراتب الشهري (د.ل)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                salary.text.trim().replaceAll(',', '.'),
              );
              if (name.text.trim().isEmpty || amount == null || amount < 0)
                return;
              Navigator.pop(ctx, {
                'name': name.text.trim(),
                'role': role.text.trim(),
                'phone': phone.text.trim(),
                'salary': amount,
              });
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      await widget.repo.addStaffMember(
        name: value['name'] as String,
        role: value['role'] as String,
        phone: value['phone'] as String,
        salary: value['salary'] as double,
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'تعذر إضافة الموظف.')),
          ),
        );
    }
  }

  Future<void> recordTransaction(
    Map<String, dynamic> person, {
    required bool isTeacher,
    required String type,
  }) async {
    final amount = TextEditingController(
      text: type == 'salary' && _salary(person) > 0
          ? _salary(person).toStringAsFixed(2)
          : '',
    );
    final note = TextEditingController();
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${type == 'advance' ? 'سلفة' : 'صرف راتب'} — ${person['name'] ?? ''}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: type == 'advance'
                      ? 'مبلغ السلفة (د.ل)'
                      : 'مبلغ الراتب المصروف (د.ل)',
                ),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                amount.text.trim().replaceAll(',', '.'),
              );
              if (v == null || v <= 0) return;
              Navigator.pop(ctx, {'amount': v, 'note': note.text.trim()});
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() => saving = true);
    try {
      await widget.repo.addPayrollTransaction(
        payeeType: isTeacher ? 'teacher' : 'staff',
        payeeId: person['id'].toString(),
        transactionType: type,
        amount: value['amount'] as double,
        paymentDate: DateTime.now(),
        note: value['note'] as String,
      );
      await load();
      await widget.onChanged();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'advance'
                  ? 'تم تسجيل السلفة ضمن المصروفات.'
                  : 'تم تسجيل صرف الراتب ضمن المصروفات.',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'تعذر حفظ العملية.')),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
