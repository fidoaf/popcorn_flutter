import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

class AppTranslations {
  AppTranslations._();

  static const appTitle = Translation({AppLanguage.en: 'Popcorn', AppLanguage.es: 'Popcorn', AppLanguage.ca: 'Popcorn'});

  static const splashSubtitle = Translation({
    AppLanguage.en: 'Filling up your bucket...',
    AppLanguage.es: 'Preparando las palomitas...',
    AppLanguage.ca: 'Preparant les mongetes...',
  });

  static const unsupportedPlatform = Translation({
    AppLanguage.en: 'Application not permitted on this operating system',
    AppLanguage.es: 'La aplicación no está permitida en este sistema operativo',
    AppLanguage.ca: "L'aplicació no està permesa en aquest sistema operatiu",
  });
}
