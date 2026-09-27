import 'package:flutter/material.dart';
import 'repository.dart';

class ReportsView extends StatefulWidget {
  final SchoolRepository repo;
  const ReportsView({super.key, required this.repo});
  @override State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  DateTime day = DateTime.now();
  Map<String, dynamic> data = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    data = await widget.repo.dailySummary(day);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final date = day.year.toString() + '-' + day.month.toString().padLeft(2, '0') + '-' + day.day.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير اليومية')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              title: Text(date),
              trailing: IconButton(
                icon: const Icon(Icons.edit_calendar),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDate: day,
                  );
                  if (d != null) {
                    setState(() => day = d);
                    await load();
                  }
                },
              ),
            ),
          ),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          if (!loading && data.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد بيانات للتقرير.')),
          if (!loading && data.isNotEmpty) Card(
            child: Column(
              children: [
                row('إجمالي الطلاب', data['students']),
                row('الحاضرون', data['present']),
                row('الغائبون', data['absent']),
                row('المتأخرون', data['late']),
                row('المدفوعات', (data['payments'] ?? 0).toString() + ' د.ل'),
                row('المصروفات', (data['expenses'] ?? 0).toString() + ' د.ل'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget row(String title, dynamic value) {
    return ListTile(title: Text(title), trailing: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)));
  }
}
