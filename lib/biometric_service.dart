import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'أكد هويتك لفتح تطبيق لامين',
        biometricOnly: true,
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
      message = 'تعذر التحقق بالبصمة. استخدم كلمة المرور من شاشة الدخول إذا لزم الأمر.';
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
                child: const Icon(Icons.fingerprint, color: Colors.white, size: 62),
              ),
              const SizedBox(height: 24),
              const Text('لامين', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('الدخول الآمن بالبصمة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                'ضع إصبعك على مستشعر البصمة لفتح التطبيق.',
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loading ? null : unlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(loading ? 'جارِ التحقق...' : 'فتح بالبصمة'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await service.disable();
                  if (mounted) widget.onAuthenticated();
                },
                child: const Text('تعطيل الدخول بالبصمة'),
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
