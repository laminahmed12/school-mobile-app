/// Validates an optional ISO date in strict YYYY-MM-DD form.
bool isValidIsoDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return false;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1 || month < 1 || month > 12 || day < 1) return false;

  final daysInMonth = <int>[31, _isLeapYear(year) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day <= daysInMonth[month - 1];
}

bool _isLeapYear(int year) =>
    year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
