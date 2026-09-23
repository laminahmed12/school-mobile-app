import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parent_provider.dart';
import '../providers/auth_provider.dart';
import '../core/repositories/school_repository.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ParentProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ParentProvider>();
    final repo = context.read<AuthProvider>().repo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة ولي الأمر'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: p.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (p.children.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('لا توجد بيانات أبناء متاحة حالياً.'),
                      ),
                    ),
                  if (p.children.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: p.selectedStudentId,
                      decoration: const InputDecoration(labelText: 'الطالب'),
                      items: p.children
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} — ${s.className}'),
                              ))
                          .toList(),
                      onChanged: (v) => v == null ? null : p.selectStudent(v),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: const Text('الرصيد المتبقي'),
                      subtitle: Text('${p.totalBalance.toStringAsFixed(3)} د.ل'),
                      leading: const Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...p.invoices.map(
                    (invoice) => Card(
                      child: ListTile(
                        title: Text('فاتورة ${invoice.number}'),
                        subtitle: Text(
                          'الإجمالي: ${invoice.total.toStringAsFixed(3)} د.ل\n'
                          'المدفوع: ${invoice.paid.toStringAsFixed(3)} د.ل\n'
                          'المتبقي: ${invoice.balance.toStringAsFixed(3)} د.ل',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'إيصال PDF',
                          icon: const Icon(Icons.picture_as_pdf),
                          onPressed: () async {
                            try {
                              final bytes = await repo.downloadReceiptPdf(invoice.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تنزيل ${bytes.length} بايت من الإيصال. اربط هنا FileSaver/Printing للحفظ النهائي.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تعذر تنزيل الإيصال: $e')),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
