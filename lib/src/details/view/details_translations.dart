import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the media details views.
class DetailsTranslations {
  DetailsTranslations._();

  static const play = Translation({AppLanguage.en: 'Play', AppLanguage.es: 'Reproducir', AppLanguage.ca: 'Reprodueix'});

  static const overview = Translation({AppLanguage.en: 'Overview', AppLanguage.es: 'Sinopsis', AppLanguage.ca: 'Sinopsi'});

  static const noOverview = Translation({
    AppLanguage.en: 'No overview available.',
    AppLanguage.es: 'No hay sinopsis disponible.',
    AppLanguage.ca: 'No hi ha sinopsi disponible.',
  });

  static const season = Translation({AppLanguage.en: 'season', AppLanguage.es: 'temporada', AppLanguage.ca: 'temporada'});

  static const seasons = Translation({AppLanguage.en: 'seasons', AppLanguage.es: 'temporadas', AppLanguage.ca: 'temporades'});

  static const episode = Translation({AppLanguage.en: 'episode', AppLanguage.es: 'episodio', AppLanguage.ca: 'episodi'});

  static const episodes = Translation({AppLanguage.en: 'episodes', AppLanguage.es: 'episodios', AppLanguage.ca: 'episodis'});

  static const videos = Translation({AppLanguage.en: 'Videos', AppLanguage.es: 'Vídeos', AppLanguage.ca: 'Vídeos'});
}
