import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the "continue watching" views.
class WatchHistoryTranslations {
  WatchHistoryTranslations._();

  static const pageTitle = Translation({AppLanguage.en: 'Continue watching', AppLanguage.es: 'Seguir viendo', AppLanguage.ca: 'Continua mirant'});

  static const emptyList = Translation({
    AppLanguage.en: "You haven't watched anything yet.",
    AppLanguage.es: 'Aún no has visto nada.',
    AppLanguage.ca: 'Encara no has vist res.',
  });

  static const removeFromHistory = Translation({
    AppLanguage.en: 'Remove from continue watching',
    AppLanguage.es: 'Quitar de seguir viendo',
    AppLanguage.ca: 'Treu de continua mirant',
  });
}
