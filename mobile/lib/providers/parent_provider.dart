import 'package:flutter/foundation.dart';
import '../core/models/app_models.dart';
import '../core/repositories/school_repository.dart';

class ParentProvider extends ChangeNotifier {
  final SchoolRepository repo;

  List<Student> children = [];
  List<InvoiceSummary> invoices = [];
  bool loading = false;
  String? selectedStudentId;

  ParentProvider(this.repo);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    children = await repo.getParentChildren();
    if (children.isNotEmpty) {
      selectedStudentId ??= children.first.id;
      invoices = await repo.getInvoices(selectedStudentId!);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> selectStudent(String id) async {
    selectedStudentId = id;
    invoices = await repo.getInvoices(id);
    notifyListeners();
  }

  double get totalBalance =>
      invoices.fold(0, (sum, invoice) => sum + invoice.balance);
}
