import 'package:intl/intl.dart';

final _wholeNaira = NumberFormat.currency(
  locale: 'en_NG',
  name: 'NGN',
  symbol: '₦',
  decimalDigits: 0,
);
final _nairaWithKobo = NumberFormat.currency(
  locale: 'en_NG',
  name: 'NGN',
  symbol: '₦',
  decimalDigits: 2,
);
final _numericAmount = RegExp(r'^[+-]?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$');
final _nairaPrefix = RegExp(r'^[+-]?₦');

/// Formats display-only NGN amounts, never values sent to APIs or calculations.
///
/// Whole amounts omit decimals by default; fractional amounts retain two kobo
/// digits. Use [alwaysShowDecimals] where the UI already displays two decimals.
/// Numeric strings and already formatted naira strings are accepted without
/// duplicating the symbol or separators. Missing/invalid values display an em
/// dash rather than implying a zero balance. Negative/refund signs are retained.
String formatNaira(Object? value, {bool alwaysShowDecimals = false}) {
  num? amount;
  if (value is num) {
    amount = value;
  } else if (value is String) {
    var text = value.trim();
    if (_nairaPrefix.hasMatch(text)) {
      text = text.replaceFirst('₦', '').trim();
    }
    if (_numericAmount.hasMatch(text)) {
      amount = num.tryParse(text.replaceAll(',', ''));
    }
  }
  if (amount == null || !amount.isFinite) return '—';
  if (amount == 0) amount = 0; // Avoid a negative-zero balance.
  final formatter = alwaysShowDecimals || amount % 1 != 0
      ? _nairaWithKobo
      : _wholeNaira;
  return formatter.format(amount);
}
