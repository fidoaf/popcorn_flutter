import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale-aware number and date formatting that follows the active
/// [Localizations] locale (decimal separators, month names, etc.).
extension LocaleFormatting on BuildContext {
  /// Formats [value] with a single decimal digit using the locale's decimal
  /// separator (e.g. `7.5` in English, `7,5` in Spanish/Catalan).
  String formatDecimal(double value) => NumberFormat.decimalPatternDigits(locale: _localeTag(this), decimalDigits: 1).format(value);

  /// Formats [date] as a medium, locale-aware date (e.g. `Aug 17, 2026`).
  String formatDate(DateTime date) => DateFormat.yMMMd(_localeTag(this)).format(date);
}

String _localeTag(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return locale.countryCode == null ? locale.languageCode : '${locale.languageCode}_${locale.countryCode}';
}
