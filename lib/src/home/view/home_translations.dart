import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the Prime Video-style home screen.
class HomeTranslations {
  HomeTranslations._();

  static const play = Translation({AppLanguage.en: 'Play', AppLanguage.es: 'Reproducir', AppLanguage.ca: 'Reprodueix'});

  static const resume = Translation({AppLanguage.en: 'Resume', AppLanguage.es: 'Reanudar', AppLanguage.ca: 'Reprèn'});

  static const details = Translation({AppLanguage.en: 'Details', AppLanguage.es: 'Detalles', AppLanguage.ca: 'Detalls'});

  static const myList = Translation({AppLanguage.en: 'My List', AppLanguage.es: 'Mi lista', AppLanguage.ca: 'La meva llista'});

  static const search = Translation({AppLanguage.en: 'Search', AppLanguage.es: 'Buscar', AppLanguage.ca: 'Cerca'});

  static const continueWatching = Translation({AppLanguage.en: 'Continue Watching', AppLanguage.es: 'Seguir viendo', AppLanguage.ca: 'Continua mirant'});

  static const trendingMovies = Translation({
    AppLanguage.en: 'Trending Movies',
    AppLanguage.es: 'Películas en tendencia',
    AppLanguage.ca: 'Pel·lícules en tendència',
  });

  static const trendingTv = Translation({AppLanguage.en: 'Trending TV Series', AppLanguage.es: 'Series en tendencia', AppLanguage.ca: 'Sèries en tendència'});

  static const seeAll = Translation({AppLanguage.en: 'See all', AppLanguage.es: 'Ver todo', AppLanguage.ca: 'Mostra-ho tot'});

  static const loadError = Translation({
    AppLanguage.en: "Couldn't load the catalogue.",
    AppLanguage.es: 'No se pudo cargar el catálogo.',
    AppLanguage.ca: "No s'ha pogut carregar el catàleg.",
  });

  static const retry = Translation({AppLanguage.en: 'Retry', AppLanguage.es: 'Reintentar', AppLanguage.ca: 'Torna-ho a provar'});
}
