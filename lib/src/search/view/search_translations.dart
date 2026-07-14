import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the search views.
class SearchTranslations {
  SearchTranslations._();

  static const pageTitle = Translation({AppLanguage.en: 'Search movies', AppLanguage.es: 'Buscar películas', AppLanguage.ca: 'Cerca de pel·lícules'});

  static const searchPlaceholder = Translation({
    AppLanguage.en: 'Search movies...',
    AppLanguage.es: 'Buscar películas...',
    AppLanguage.ca: 'Cerca pel·lícules...',
  });

  static const searchButton = Translation({AppLanguage.en: 'Search', AppLanguage.es: 'Buscar', AppLanguage.ca: 'Cerca'});

  static const idleHint = Translation({
    AppLanguage.en: 'Type a title to find movies.',
    AppLanguage.es: 'Escribe un título para encontrar películas.',
    AppLanguage.ca: 'Escriu un títol per trobar pel·lícules.',
  });

  static const emptyResults = Translation({
    AppLanguage.en: 'No movies found.',
    AppLanguage.es: 'No se encontraron películas.',
    AppLanguage.ca: "No s'han trobat pel·lícules.",
  });

  static const errorTitle = Translation({AppLanguage.en: 'Search failed', AppLanguage.es: 'La búsqueda falló', AppLanguage.ca: 'La cerca ha fallat'});
}
