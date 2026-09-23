import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/app_models.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  UserRole role = UserRole.teacher;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, size: 64),
                  const SizedBox(height: 12),
                  const Text('نظام إدارة المدارس',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<UserRole>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'الدور'),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.teacher,
                        child: Text('معلم'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.parent,
                        child: Text('ولي أمر'),
                      ),
                    ],
                    onChanged: (v) => setState(() => role = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.loading
                        ? null
                        : () async {
                            final error = await context.read<AuthProvider>().login(
                                  username.text.trim(),
                                  password.text,
                                  role,
                                );
                            if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(error)));
                            }
                          },
                    child: auth.loading
                        ? const CircularProgressIndicator()
                        : const Text('دخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
