import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(double amount) => _inr.format(amount);

  static String formatDecimal(double amount) => _inrDecimal.format(amount);

  static String formatCompact(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} L';
    }
    return format(amount);
  }
}

class IndexFormatter {
  IndexFormatter._();

  static final NumberFormat _index = NumberFormat('#,##0.00', 'en_IN');
  static final NumberFormat _change = NumberFormat('#,##0.00', 'en_IN');

  static String format(double value) => _index.format(value);

  static String formatChange(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${_change.format(value)}';
  }

  static String formatPercent(double percent) {
    final prefix = percent >= 0 ? '+' : '';
    return '$prefix${percent.toStringAsFixed(2)}%';
  }
}

class DateFormatter {
  DateFormatter._();

  static final DateFormat _display = DateFormat('dd MMM yyyy');
  static final DateFormat _displayTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _short = DateFormat('dd/MM/yyyy');

  static String display(DateTime date) => _display.format(date.toLocal());
  static String displayWithTime(DateTime date) => _displayTime.format(date.toLocal());
  static String short(DateTime date) => _short.format(date.toLocal());

  /// Parse API date-only strings (yyyy-MM-dd) without UTC timezone shift.
  static DateTime parseDateOnly(String iso) {
    final datePart = iso.split('T').first.trim();
    final parts = datePart.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    return DateTime.parse(iso).toLocal();
  }

  static String expiryLabel(String iso) {
    final d = parseDateOnly(iso);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final showYear = d.year != now.year;
    final dayPart = '${d.day} ${months[d.month - 1]}${showYear ? ' ${d.year}' : ''}';
    return '${weekdays[d.weekday - 1]}, $dayPart';
  }
}

class GreetingHelper {
  GreetingHelper._();

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
