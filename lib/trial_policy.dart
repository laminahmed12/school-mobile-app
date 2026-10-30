/// Subscription trial rules shared by the UI and automated tests.
DateTime? schoolTrialEnd(Map<String, dynamic>? school) {
  final raw = school?['trial_started_at']?.toString();
  if (raw == null || raw.isEmpty) return null;
  final started = DateTime.tryParse(raw)?.toUtc();
  if (started == null) return null;

  // The commercial requirement is exactly 30 x 24 hours, not one calendar month.
  return started.add(const Duration(days: 30));
}
