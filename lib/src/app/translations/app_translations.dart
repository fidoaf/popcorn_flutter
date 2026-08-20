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

  static const landingTagline = Translation({
    AppLanguage.en: 'Your pocket cinema for movies and TV shows',
    AppLanguage.es: 'Tu cine de bolsillo para películas y series',
    AppLanguage.ca: 'El teu cinema de butxaca per a pel·lícules i sèries',
  });

  static const landingHeroTitle = Translation({
    AppLanguage.en: 'Watch movies and TV shows',
    AppLanguage.es: 'Películas y series a tu alcance',
    AppLanguage.ca: 'Pel·lícules i sèries al teu abast',
  });

  static const landingHeroSubtitle = Translation({
    AppLanguage.en:
        'Discover popular movies and TV shows, watch trailers and keep track of everything you love. Sign in with your Google account to get started — Popcorn is free, with no subscription and no ads.',
    AppLanguage.es:
        'Descubre películas y series populares, mira tráilers y guarda todo lo que te gusta. Inicia sesión con tu cuenta de Google para empezar: Popcorn es gratis, sin suscripción ni anuncios.',
    AppLanguage.ca:
        'Descobreix pel·lícules i sèries populars, mira tràilers i desa tot el que t\'agrada. Inicia la sessió amb el teu compte de Google per començar: Popcorn és gratis, sense subscripció ni anuncis.',
  });

  static const landingEnterFree = Translation({
    AppLanguage.en: 'Sign in and start watching',
    AppLanguage.es: 'Inicia sesión y empieza a ver',
    AppLanguage.ca: 'Inicia la sessió i comença a veure',
  });

  static const landingBrowseCatalog = Translation({
    AppLanguage.en: 'Browse the catalog',
    AppLanguage.es: 'Explorar el catálogo',
    AppLanguage.ca: 'Explorar el catàleg',
  });

  static const landingFreeTag = Translation({
    AppLanguage.en: 'Free · Sign in with Google · No ads',
    AppLanguage.es: 'Gratis · Inicia sesión con Google · Sin anuncios',
    AppLanguage.ca: 'Gratis · Inicia la sessió amb Google · Sense anuncis',
  });

  static const landingNavMovies = Translation({AppLanguage.en: 'Movies', AppLanguage.es: 'Películas', AppLanguage.ca: 'Pel·lícules'});

  static const landingNavTvShows = Translation({AppLanguage.en: 'TV shows', AppLanguage.es: 'Series', AppLanguage.ca: 'Sèries'});

  static const landingNavHome = Translation({AppLanguage.en: 'Home', AppLanguage.es: 'Inicio', AppLanguage.ca: 'Inici'});

  static const landingFeaturesTitle = Translation({
    AppLanguage.en: 'Everything you love, all in one place',
    AppLanguage.es: 'Todo lo que te gusta, en un solo lugar',
    AppLanguage.ca: 'Tot el que t\'agrada, en un sol lloc',
  });

  static const landingFeaturesBody = Translation({
    AppLanguage.en: 'Trending titles, trailers, favorites and your watch history — organized and ready whenever you are.',
    AppLanguage.es: 'Títulos en tendencia, tráilers, favoritas y tu historial: organizados y listos cuando quieras.',
    AppLanguage.ca: 'Títols de tendència, tràilers, preferides i el teu historial: organitzats i a punt quan vulguis.',
  });

  static const landingDescription = Translation({
    AppLanguage.en:
        'Popcorn is a free app for discovering movies and TV shows. Browse trending titles, watch trailers, and keep track of your favorites and watch history — all in one place.',
    AppLanguage.es:
        'Popcorn es una app gratuita para descubrir películas y series. Explora títulos en tendencia, mira tráilers y guarda tus favoritas y tu historial, todo en un solo lugar.',
    AppLanguage.ca:
        'Popcorn és una app gratuïta per descobrir pel·lícules i sèries. Explora títols de tendència, mira tràilers i desa les teves preferides i el teu historial, tot en un sol lloc.',
  });

  static const landingFeatureBrowse = Translation({
    AppLanguage.en: 'Browse trending movies and TV shows',
    AppLanguage.es: 'Explora películas y series en tendencia',
    AppLanguage.ca: 'Explora pel·lícules i sèries de tendència',
  });

  static const landingFeatureBrowseBody = Translation({
    AppLanguage.en: 'A fresh, always-updated catalog of the titles everyone is watching right now.',
    AppLanguage.es: 'Un catálogo fresco y siempre actualizado con los títulos que todos ven ahora.',
    AppLanguage.ca: 'Un catàleg fresc i sempre actualitzat amb els títols que tothom veu ara.',
  });

  static const landingFeatureTrailers = Translation({
    AppLanguage.en: 'Watch trailers and previews',
    AppLanguage.es: 'Mira tráilers y avances',
    AppLanguage.ca: 'Mira tràilers i avanços',
  });

  static const landingFeatureTrailersBody = Translation({
    AppLanguage.en: 'Preview before you press play with trailers for movies and shows.',
    AppLanguage.es: 'Echa un vistazo antes de darle al play con tráilers de pelis y series.',
    AppLanguage.ca: 'Fes-hi un cop d\'ull abans de prémer play amb tràilers de pel·lícules i sèries.',
  });

  static const landingFeatureFavorites = Translation({
    AppLanguage.en: 'Save favorites and track your watch history',
    AppLanguage.es: 'Guarda favoritas y sigue tu historial',
    AppLanguage.ca: 'Desa preferides i segueix el teu historial',
  });

  static const landingFeatureFavoritesBody = Translation({
    AppLanguage.en: 'Keep everything you love in one list and pick up right where you left off.',
    AppLanguage.es: 'Guarda todo lo que te gusta en una lista y continúa donde lo dejaste.',
    AppLanguage.ca: 'Desa tot el que t\'agrada en una llista i continua on ho vas deixar.',
  });

  static const landingFooterRights = Translation({
    AppLanguage.en: 'Popcorn · A free movie & TV discovery app',
    AppLanguage.es: 'Popcorn · App gratuita para descubrir cine y series',
    AppLanguage.ca: 'Popcorn · App gratuïta per descobrir cinema i sèries',
  });

  static const landingEnter = Translation({AppLanguage.en: 'Enter Popcorn', AppLanguage.es: 'Entrar en Popcorn', AppLanguage.ca: 'Entra a Popcorn'});
}
