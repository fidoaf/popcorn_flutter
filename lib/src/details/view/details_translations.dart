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

  static const seasonsTitle = Translation({AppLanguage.en: 'Seasons', AppLanguage.es: 'Temporadas', AppLanguage.ca: 'Temporades'});

  static const noEpisodes = Translation({
    AppLanguage.en: 'No episodes available.',
    AppLanguage.es: 'No hay episodios disponibles.',
    AppLanguage.ca: 'No hi ha episodis disponibles.',
  });

  static const episodesError = Translation({
    AppLanguage.en: 'Could not load episodes.',
    AppLanguage.es: 'No se pudieron cargar los episodios.',
    AppLanguage.ca: 'No s\'han pogut carregar els episodis.',
  });

  static const videos = Translation({AppLanguage.en: 'Videos', AppLanguage.es: 'Vídeos', AppLanguage.ca: 'Vídeos'});

  static const director = Translation({AppLanguage.en: 'Director', AppLanguage.es: 'Director', AppLanguage.ca: 'Director'});

  static const cast = Translation({AppLanguage.en: 'Cast', AppLanguage.es: 'Reparto', AppLanguage.ca: 'Repartiment'});
}
