import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static String formatCurrency(double amount) {
    return _currencyFormatter.format(amount);
  }

  static String formatPower(double kW) {
    return '${kW.toStringAsFixed(0)} kW';
  }

  static String formatDistance(double km, {bool useMiles = true}) {
    if (useMiles) {
      final miles = km * 0.621371;
      return '${miles.toStringAsFixed(1)} mi';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}
