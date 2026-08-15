import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the search views.
class SearchTranslations {
  SearchTranslations._();

  static const pageTitle = Translation({AppLanguage.en: 'Search', AppLanguage.es: 'Buscar', AppLanguage.ca: 'Cerca'});

  static const searchPlaceholder = Translation({AppLanguage.en: 'Search titles...', AppLanguage.es: 'Buscar títulos...', AppLanguage.ca: 'Cerca títols...'});

  static const searchButton = Translation({AppLanguage.en: 'Search', AppLanguage.es: 'Buscar', AppLanguage.ca: 'Cerca'});

  static const mediaMovies = Translation({AppLanguage.en: 'Movies', AppLanguage.es: 'Películas', AppLanguage.ca: 'Pel·lícules'});

  static const mediaTvSeries = Translation({AppLanguage.en: 'TV Series', AppLanguage.es: 'Series', AppLanguage.ca: 'Sèries'});

  static const idleHint = Translation({
    AppLanguage.en: 'Type a title to find movies and TV series.',
    AppLanguage.es: 'Escribe un título para encontrar películas y series.',
    AppLanguage.ca: 'Escriu un títol per trobar pel·lícules i sèries.',
  });

  static const emptyResults = Translation({
    AppLanguage.en: 'No results found.',
    AppLanguage.es: 'No se encontraron resultados.',
    AppLanguage.ca: "No s'han trobat resultats.",
  });

  static const errorTitle = Translation({AppLanguage.en: 'Search failed', AppLanguage.es: 'La búsqueda falló', AppLanguage.ca: 'La cerca ha fallat'});

  static const playButton = Translation({AppLanguage.en: 'Play', AppLanguage.es: 'Reproducir', AppLanguage.ca: 'Reprodueix'});

  static const tba = Translation({AppLanguage.en: 'TBA', AppLanguage.es: 'Por anunciar', AppLanguage.ca: 'Per anunciar'});

  static const trendingTitle = Translation({
    AppLanguage.en: 'Trending this week',
    AppLanguage.es: 'Tendencias de la semana',
    AppLanguage.ca: 'Tendències de la setmana',
  });
}
