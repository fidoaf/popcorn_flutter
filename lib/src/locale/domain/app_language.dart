import 'dart:ui';

enum AppLanguage {
  en,
  es,
  ca;

  Locale get locale {
    return switch (this) {
      AppLanguage.en => const Locale('en'),
      AppLanguage.es => const Locale('es'),
      AppLanguage.ca => const Locale('ca', 'ES'),
    };
  }

  static AppLanguage fromLocale(Locale locale) {
    return values.firstWhere((language) => language.locale.languageCode == locale.languageCode, orElse: () => en);
  }
}
