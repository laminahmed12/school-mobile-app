import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';

bool shouldEngageBiometricLockForLifecycle({
  required AppLifecycleState state,
  required bool biometricEnabled,
  required bool hasAuthenticatedAccess,
}) {
  final appWentToBackground =
      state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
  return appWentToBackground && biometricEnabled && hasAuthenticatedAccess;
}

class LaminBiometricService {
  static const _enabledKey = 'lamin.biometric.enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get enabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> canUseBiometric() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'أكد هويتك لفتح تطبيق لامين',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> enable() async {
    if (!await canUseBiometric()) return false;
    final ok = await authenticate();
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    return true;
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
  }
}

class BiometricLockPage extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const BiometricLockPage({super.key, required this.onAuthenticated});

  @override
  State<BiometricLockPage> createState() => _BiometricLockPageState();
}

class _BiometricLockPageState extends State<BiometricLockPage> {
  final service = LaminBiometricService();
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unlock());
  }

  Future<void> unlock() async {
    if (loading) return;
    setState(() {
      loading = true;
      message = null;
    });
    final ok = await service.authenticate();
    if (!mounted) return;
    if (ok) {
      widget.onAuthenticated();
      return;
    }
    setState(() {
      loading = false;
      message =
          'تعذر فتح قفل الجهاز. استخدم وسيلة قفل الشاشة أو كلمة المرور.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: const Color(0xFF155D4A),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Colors.white,
                  size: 62,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'لامين',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'الدخول الآمن',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'استخدم البصمة أو وسيلة قفل الشاشة المعتمدة على جهازك.',
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loading ? null : unlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(loading ? 'جارِ التحقق...' : 'فتح التطبيق'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        await service.disable();
                        await db.auth.signOut();
                      },
                icon: const Icon(Icons.password_outlined),
                label: const Text('استخدام كلمة المرور'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DeviceSecurityService {
  final LaminBiometricService _inner = LaminBiometricService();
  Future<bool> get enabled => _inner.enabled;
  Future<bool> enable() => _inner.enable();
  Future<void> disable() => _inner.disable();
}

class DeviceLockPage extends BiometricLockPage {
  const DeviceLockPage({super.key, required super.onAuthenticated});
}
