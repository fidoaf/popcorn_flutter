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

  static const landingDescription = Translation({
    AppLanguage.en: 'Discover trending films and series, watch trailers, and keep track of your favorites — all in one place.',
    AppLanguage.es: 'Descubre películas y series en tendencia, mira tráilers y guarda tus favoritas, todo en un solo lugar.',
    AppLanguage.ca: 'Descobreix pel·lícules i sèries de tendència, mira tràilers i desa les teves preferides, tot en un sol lloc.',
  });

  static const landingFeatureBrowse = Translation({
    AppLanguage.en: 'Browse trending movies and TV shows',
    AppLanguage.es: 'Explora películas y series en tendencia',
    AppLanguage.ca: 'Explora pel·lícules i sèries de tendència',
  });

  static const landingFeatureTrailers = Translation({
    AppLanguage.en: 'Watch trailers and previews',
    AppLanguage.es: 'Mira tráilers y avances',
    AppLanguage.ca: 'Mira tràilers i avanços',
  });

  static const landingFeatureFavorites = Translation({
    AppLanguage.en: 'Save favorites and track your watch history',
    AppLanguage.es: 'Guarda favoritas y sigue tu historial',
    AppLanguage.ca: 'Desa preferides i segueix el teu historial',
  });

  static const landingEnter = Translation({AppLanguage.en: 'Enter Popcorn', AppLanguage.es: 'Entrar en Popcorn', AppLanguage.ca: 'Entra a Popcorn'});
}
