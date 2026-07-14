import 'dart:ui';

import 'package:popcorn_flutter/src/locale/domain/app_language.dart';

class Translation {
  final Map<AppLanguage, String> _values;
  final AppLanguage fallback;

  const Translation(this._values, {this.fallback = AppLanguage.en});

  String of(AppLanguage language) => _values[language] ?? _values[fallback]!;

  String translate(Locale locale) => of(AppLanguage.fromLocale(locale));
}
