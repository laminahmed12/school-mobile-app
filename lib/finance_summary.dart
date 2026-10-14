/// Pure financial summary arithmetic shared by the repository and unit tests.
///
/// Active allocations reduce only the obligation they explicitly reference.
/// Any payment with allocation history (including reversed rows) is excluded
/// from the legacy fallback to prevent double counting.
Map<String, double> calculateStudentFinancialTotals({
  required List<Map<String, dynamic>> fees,
  required List<Map<String, dynamic>> payments,
  required List<Map<String, dynamic>> openingBalances,
  required List<Map<String, dynamic>> allocationRows,
}) {
  final feeIds = fees
      .map((row) => row['id']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();

  final allocatedPaymentIds = allocationRows
      .map((row) => row['payment_id']?.toString())
      .whereType<String>()
      .toSet();
  final feeAllocated = <String, double>{};
  final openingAllocated = <String, double>{};

  for (final row in allocationRows) {
    if (row['reversed_at'] != null) continue;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final feeId = row['fee_assessment_id']?.toString();
    final openingId = row['opening_balance_id']?.toString();
    if (feeId != null && feeIds.contains(feeId)) {
      feeAllocated.update(feeId, (value) => value + amount,
          ifAbsent: () => amount);
    }
    if (openingId != null && openingId.isNotEmpty) {
      openingAllocated.update(openingId, (value) => value + amount,
          ifAbsent: () => amount);
    }
  }

  final legacyPaidByFee = <String, double>{};
  for (final row in payments) {
    final paymentId = row['id']?.toString();
    final feeId = row['fee_assessment_id']?.toString();
    if (paymentId == null ||
        feeId == null ||
        !feeIds.contains(feeId) ||
        allocatedPaymentIds.contains(paymentId)) {
      continue;
    }
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    legacyPaidByFee.update(feeId, (value) => value + amount,
        ifAbsent: () => amount);
  }

  double totalFee = 0, discount = 0, opening = 0, paid = 0, remaining = 0;
  for (final row in fees) {
    final id = row['id']?.toString();
    final fee = (row['total_fee'] as num?)?.toDouble() ?? 0;
    final reduction = (row['discount'] as num?)?.toDouble() ?? 0;
    totalFee += fee;
    discount += reduction;
    final applied = (id == null ? 0 : (feeAllocated[id] ?? 0)) +
        (id == null ? 0 : (legacyPaidByFee[id] ?? 0));
    paid += applied;
    remaining +=
        (fee - reduction - applied).clamp(0, double.infinity).toDouble();
  }

  for (final row in openingBalances) {
    final id = row['id']?.toString();
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    opening += amount;
    final applied = id == null ? 0 : (openingAllocated[id] ?? 0);
    paid += applied;
    remaining += (amount - applied).clamp(0, double.infinity).toDouble();
  }

  return {
    'fees': totalFee,
    'discount': discount,
    'opening_balance': opening,
    'paid': paid,
    'remaining': remaining,
  };
}
