import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the streaming-style home screen.
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

  static const newSeason = Translation({AppLanguage.en: 'NEW SEASON', AppLanguage.es: 'NUEVA TEMPORADA', AppLanguage.ca: 'NOVA TEMPORADA'});

  static const seasonPremiere = Translation({
    AppLanguage.en: 'SEASON PREMIERE',
    AppLanguage.es: 'ESTRENO DE TEMPORADA',
    AppLanguage.ca: 'ESTRENA DE TEMPORADA',
  });

  static const newSeries = Translation({AppLanguage.en: 'NEW SERIES', AppLanguage.es: 'NUEVA SERIE', AppLanguage.ca: 'SÈRIE NOVA'});

  static const newMovie = Translation({AppLanguage.en: 'NEW MOVIE', AppLanguage.es: 'NUEVA PELÍCULA', AppLanguage.ca: 'PEL·LÍCULA NOVA'});

  static const trendingTrailers = Translation({
    AppLanguage.en: 'Trending trailers',
    AppLanguage.es: 'Tráilers en tendencia',
    AppLanguage.ca: 'Tràilers en tendència',
  });

  static const liveTv = Translation({AppLanguage.en: 'Live TV', AppLanguage.es: 'TV en directo', AppLanguage.ca: 'TV en directe'});
  static const allCountries = Translation({AppLanguage.en: 'All countries', AppLanguage.es: 'Todos los países', AppLanguage.ca: 'Tots els països'});
  static const country = Translation({AppLanguage.en: 'Country', AppLanguage.es: 'País', AppLanguage.ca: 'País'});
  static const epg = Translation({AppLanguage.en: 'Programme guide', AppLanguage.es: 'Guía de programación', AppLanguage.ca: 'Guia de programació'});
  static const epgEmpty = Translation({
    AppLanguage.en: 'No programme guide is available for this channel.',
    AppLanguage.es: 'No hay programación disponible para este canal.',
    AppLanguage.ca: 'No hi ha programació disponible per a aquest canal.',
  });
  static const epgError = Translation({
    AppLanguage.en: 'Unable to load the programme guide.',
    AppLanguage.es: 'No se pudo cargar la programación.',
    AppLanguage.ca: "No s'ha pogut carregar la programació.",
  });

  static const liveTvAttribution = Translation({
    AppLanguage.en: 'Channels provided by iptv-org',
    AppLanguage.es: 'Canales proporcionados por iptv-org',
    AppLanguage.ca: 'Canals proporcionats per iptv-org',
  });

  static const liveTvLoading = Translation({
    AppLanguage.en: 'Loading live channels…',
    AppLanguage.es: 'Cargando canales en directo…',
    AppLanguage.ca: 'Carregant canals en directe…',
  });

  static const liveTvUnavailable = Translation({
    AppLanguage.en: "Live TV isn't available right now.",
    AppLanguage.es: 'La TV en directo no está disponible ahora.',
    AppLanguage.ca: 'La TV en directe no està disponible ara.',
  });

  static const noLiveChannels = Translation({
    AppLanguage.en: 'No live channels are available.',
    AppLanguage.es: 'No hay canales en directo disponibles.',
    AppLanguage.ca: 'No hi ha canals en directe disponibles.',
  });

  static const liveLabel = Translation({AppLanguage.en: 'LIVE', AppLanguage.es: 'EN DIRECTO', AppLanguage.ca: 'EN DIRECTE'});

  static const seeAll = Translation({AppLanguage.en: 'See all', AppLanguage.es: 'Ver todo', AppLanguage.ca: 'Mostra-ho tot'});

  static const loadError = Translation({
    AppLanguage.en: "Couldn't load the catalogue.",
    AppLanguage.es: 'No se pudo cargar el catálogo.',
    AppLanguage.ca: "No s'ha pogut carregar el catàleg.",
  });

  static const retry = Translation({AppLanguage.en: 'Retry', AppLanguage.es: 'Reintentar', AppLanguage.ca: 'Torna-ho a provar'});
}
