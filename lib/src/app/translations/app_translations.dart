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

  static const updateAvailableMessage = Translation({
    AppLanguage.en: 'A new version is available.',
    AppLanguage.es: 'Hay una nueva versión disponible.',
    AppLanguage.ca: 'Hi ha una nova versió disponible.',
  });

  static const updateReload = Translation({AppLanguage.en: 'Reload', AppLanguage.es: 'Recargar', AppLanguage.ca: 'Recarregar'});

  static const pushTitle = Translation({AppLanguage.en: 'Notifications', AppLanguage.es: 'Notificaciones', AppLanguage.ca: 'Notificacions'});
  static const pushEnable = Translation({AppLanguage.en: 'Enable', AppLanguage.es: 'Activar', AppLanguage.ca: 'Activa'});
  static const pushDisable = Translation({AppLanguage.en: 'Disable', AppLanguage.es: 'Desactivar', AppLanguage.ca: 'Desactiva'});
  static const pushEnableMessage = Translation({
    AppLanguage.en: 'Receive Popcorn announcements on this browser, even when the app is closed. You can disable them here at any time.',
    AppLanguage.es: 'Recibe anuncios de Popcorn en este navegador, incluso con la app cerrada. Puedes desactivarlos aquí en cualquier momento.',
    AppLanguage.ca: 'Rep anuncis de Popcorn en aquest navegador, fins i tot amb l\'app tancada. Els pots desactivar aquí en qualsevol moment.',
  });
  static const pushDisableMessage = Translation({
    AppLanguage.en: 'Disable Popcorn push notifications on this browser?',
    AppLanguage.es: '¿Desactivar las notificaciones de Popcorn en este navegador?',
    AppLanguage.ca: 'Vols desactivar les notificacions de Popcorn en aquest navegador?',
  });
  static const pushEnabled = Translation({
    AppLanguage.en: 'Notifications enabled.',
    AppLanguage.es: 'Notificaciones activadas.',
    AppLanguage.ca: 'Notificacions activades.',
  });
  static const pushDisabled = Translation({
    AppLanguage.en: 'Notifications disabled.',
    AppLanguage.es: 'Notificaciones desactivadas.',
    AppLanguage.ca: 'Notificacions desactivades.',
  });
  static const pushError = Translation({
    AppLanguage.en: 'Could not update notifications:',
    AppLanguage.es: 'No se pudieron actualizar las notificaciones:',
    AppLanguage.ca: 'No s\'han pogut actualitzar les notificacions:',
  });

  static const installAppTitle = Translation({AppLanguage.en: 'Install Popcorn', AppLanguage.es: 'Instala Popcorn', AppLanguage.ca: 'Instal·la Popcorn'});

  static const installAppMessage = Translation({
    AppLanguage.en: 'For a better experience, add Popcorn to your device for quick access whenever you want.',
    AppLanguage.es: 'Para una mejor experiencia, añade Popcorn a tu dispositivo y accede rápidamente cuando quieras.',
    AppLanguage.ca: 'Per a una millor experiència, afegeix Popcorn al teu dispositiu i accedeix-hi ràpidament quan vulguis.',
  });

  static const installIosInstructionsTitle = Translation({
    AppLanguage.en: 'How to install on iPhone/iPad:',
    AppLanguage.es: 'Cómo instalar en iPhone/iPad:',
    AppLanguage.ca: 'Com instal·lar a l’iPhone/iPad:',
  });

  static const installIosInstructionShare = Translation({
    AppLanguage.en: 'Tap the Share button in your browser',
    AppLanguage.es: 'Toca el botón Compartir del navegador',
    AppLanguage.ca: 'Toca el botó Compartir del navegador',
  });

  static const installIosInstructionHome = Translation({
    AppLanguage.en: 'Select “Add to Home Screen”',
    AppLanguage.es: 'Selecciona “Añadir a pantalla de inicio”',
    AppLanguage.ca: 'Selecciona “Afegir a la pantalla d’inici”',
  });

  static const installIosInstructionAdd = Translation({AppLanguage.en: 'Tap “Add”', AppLanguage.es: 'Toca “Añadir”', AppLanguage.ca: 'Toca “Afegir”'});

  static const installBrowserInstructionsTitle = Translation({
    AppLanguage.en: 'How to install:',
    AppLanguage.es: 'Cómo instalar:',
    AppLanguage.ca: 'Com instal·lar:',
  });

  static const installBrowserInstructionMenu = Translation({
    AppLanguage.en: 'Open your browser menu',
    AppLanguage.es: 'Abre el menú del navegador',
    AppLanguage.ca: 'Obre el menú del navegador',
  });

  static const installBrowserInstructionApp = Translation({
    AppLanguage.en: 'Choose “Install app” or “Add to Home Screen”',
    AppLanguage.es: 'Elige “Instalar aplicación” o “Añadir a pantalla de inicio”',
    AppLanguage.ca: 'Tria “Instal·la l’aplicació” o “Afegeix a la pantalla d’inici”',
  });

  static const installLater = Translation({AppLanguage.en: 'Later', AppLanguage.es: 'Más tarde', AppLanguage.ca: 'Més tard'});

  static const unsupportedPlatform = Translation({
    AppLanguage.en: 'Application not permitted on this operating system',
    AppLanguage.es: 'La aplicación no está permitida en este sistema operativo',
    AppLanguage.ca: "L'aplicació no està permesa en aquest sistema operatiu",
  });

  static const maintenanceTitle = Translation({AppLanguage.en: 'Under maintenance', AppLanguage.es: 'En mantenimiento', AppLanguage.ca: 'En manteniment'});

  static const maintenanceMessage = Translation({
    AppLanguage.en: "We'll be back shortly. Please try again later.",
    AppLanguage.es: 'Volveremos enseguida. Inténtalo de nuevo más tarde.',
    AppLanguage.ca: 'Tornarem de seguida. Torna-ho a provar més tard.',
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
