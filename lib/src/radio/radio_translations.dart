import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

abstract final class RadioTranslations {
  static const title = Translation({AppLanguage.en: 'Radio stations', AppLanguage.es: 'Emisoras de radio', AppLanguage.ca: 'Emissores de ràdio'});
  static const attribution = Translation({
    AppLanguage.en: 'Stations provided by Radio Browser',
    AppLanguage.es: 'Emisoras proporcionadas por Radio Browser',
    AppLanguage.ca: 'Emissores proporcionades per Radio Browser',
  });
  static const loading = Translation({
    AppLanguage.en: 'Loading radio stations…',
    AppLanguage.es: 'Cargando emisoras de radio…',
    AppLanguage.ca: 'Carregant emissores de ràdio…',
  });
  static const unavailable = Translation({
    AppLanguage.en: 'Radio stations are unavailable right now.',
    AppLanguage.es: 'Las emisoras de radio no están disponibles ahora.',
    AppLanguage.ca: 'Les emissores de ràdio no estan disponibles ara.',
  });
  static const empty = Translation({
    AppLanguage.en: 'No radio stations are available.',
    AppLanguage.es: 'No hay emisoras de radio disponibles.',
    AppLanguage.ca: 'No hi ha emissores de ràdio disponibles.',
  });
  static const playbackError = Translation({
    AppLanguage.en: 'Unable to play this station. Try again or choose another station.',
    AppLanguage.es: 'No se pudo reproducir esta emisora. Inténtalo de nuevo o elige otra.',
    AppLanguage.ca: "No s'ha pogut reproduir aquesta emissora. Torna-ho a provar o tria'n una altra.",
  });
  static const pause = Translation({AppLanguage.en: 'Pause', AppLanguage.es: 'Pausar', AppLanguage.ca: 'Pausa'});
  static const volume = Translation({AppLanguage.en: 'Volume', AppLanguage.es: 'Volumen', AppLanguage.ca: 'Volum'});
}
