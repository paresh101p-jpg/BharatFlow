import 'package:intl/intl.dart';

class AppDateFormatter {
  static const String universalFormat = 'dd/MM/yyyy';
  static const String universalDateTimeFormat = 'dd/MM/yyyy, hh:mm a';

  /// Standardizes any date to DD/MM/YYYY
  static String format(DateTime date) {
    return DateFormat(universalFormat).format(date);
  }

  /// Standardizes any date to DD/MM/YYYY, HH:MM AM/PM
  static String formatDateTime(DateTime date) {
    return DateFormat(universalDateTimeFormat).format(date);
  }

  /// Parses various date strings and returns standardized DD/MM/YYYY
  static String formatString(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      // Try parsing common formats
      DateTime? parsed;
      
      // Try ISO 8601
      parsed = DateTime.tryParse(dateStr);
      
      if (parsed == null) {
        // Try DD-MM-YYYY or DD/MM/YYYY
        final parts = dateStr.split(RegExp(r'[/.-]'));
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          parsed = DateTime(year, month, day);
        }
      }
      
      if (parsed != null) {
        return format(parsed);
      }
    } catch (_) {}
    return dateStr;
  }
}
