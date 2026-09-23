import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/teacher_provider.dart';
import '../providers/auth_provider.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TeacherProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TeacherProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلم'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (p.message != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(p.message!),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: p.students.length,
                    itemBuilder: (_, i) {
                      final s = p.students[i];
                      final present = p.attendance[s.id] ?? true;
                      return SwitchListTile(
                        title: Text(s.name),
                        subtitle: Text(s.className),
                        value: present,
                        onChanged: (v) => p.setPresent(s.id, v),
                        secondary: Icon(
                          present ? Icons.check_circle : Icons.cancel,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: p.students.isEmpty ? null : p.saveAttendance,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('حفظ الحضور'),
      ),
    );
  }
}
