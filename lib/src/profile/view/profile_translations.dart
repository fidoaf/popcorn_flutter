import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the profile switcher and editor.
class ProfileTranslations {
  ProfileTranslations._();

  static const whosWatching = Translation({AppLanguage.en: "Who's watching?", AppLanguage.es: '¿Quién está viendo?', AppLanguage.ca: 'Qui està mirant?'});

  static const addProfile = Translation({AppLanguage.en: 'Add profile', AppLanguage.es: 'Añadir perfil', AppLanguage.ca: 'Afegeix un perfil'});

  static const editProfile = Translation({AppLanguage.en: 'Edit profile', AppLanguage.es: 'Editar perfil', AppLanguage.ca: 'Edita el perfil'});

  static const newProfile = Translation({AppLanguage.en: 'New profile', AppLanguage.es: 'Nuevo perfil', AppLanguage.ca: 'Perfil nou'});

  static const profileName = Translation({AppLanguage.en: 'Profile name', AppLanguage.es: 'Nombre del perfil', AppLanguage.ca: 'Nom del perfil'});

  static const changePicture = Translation({AppLanguage.en: 'Change picture', AppLanguage.es: 'Cambiar imagen', AppLanguage.ca: 'Canvia la imatge'});

  static const adjustPhoto = Translation({AppLanguage.en: 'Adjust photo', AppLanguage.es: 'Ajustar foto', AppLanguage.ca: 'Ajusta la foto'});

  static const adjustPhotoHint = Translation({
    AppLanguage.en: 'Drag to reposition · scroll or pinch to zoom',
    AppLanguage.es: 'Arrastra para reposicionar · desliza o pellizca para ampliar',
    AppLanguage.ca: 'Arrossega per reposicionar · desplaça o pessiga per ampliar',
  });

  static const save = Translation({AppLanguage.en: 'Save', AppLanguage.es: 'Guardar', AppLanguage.ca: 'Desa'});

  static const cancel = Translation({AppLanguage.en: 'Cancel', AppLanguage.es: 'Cancelar', AppLanguage.ca: 'Cancel·la'});

  static const create = Translation({AppLanguage.en: 'Create', AppLanguage.es: 'Crear', AppLanguage.ca: 'Crea'});

  static const signOut = Translation({AppLanguage.en: 'Sign out', AppLanguage.es: 'Cerrar sesión', AppLanguage.ca: 'Tanca la sessió'});

  static const accountSettings = Translation({
    AppLanguage.en: 'Account settings',
    AppLanguage.es: 'Ajustes de la cuenta',
    AppLanguage.ca: 'Configuració del compte',
  });

  static const countryOrRegion = Translation({AppLanguage.en: 'Country or region', AppLanguage.es: 'País o región', AppLanguage.ca: 'País o regió'});

  static const localPlayerServer = Translation({
    AppLanguage.en: 'Use local player server',
    AppLanguage.es: 'Usar servidor de reproducción local',
    AppLanguage.ca: 'Utilitza el servidor de reproducció local',
  });

  static const localPlayerServerHint = Translation({
    AppLanguage.en: 'Starts the bundled server when needed. Restart the app to apply. Off uses the configured hosted server.',
    AppLanguage.es: 'Inicia el servidor incluido cuando es necesario. Reinicia la aplicación para aplicar. Desactivado usa el servidor configurado.',
    AppLanguage.ca: 'Inicia el servidor inclòs quan cal. Reinicia l’aplicació per aplicar-ho. Desactivat utilitza el servidor configurat.',
  });

  static const localPlayerServerFailed = Translation({
    AppLanguage.en: 'The local player server could not run.',
    AppLanguage.es: 'No se ha podido ejecutar el servidor local.',
    AppLanguage.ca: 'No s’ha pogut executar el servidor local.',
  });

  static const useHostedServer = Translation({
    AppLanguage.en: 'Disable local mode and use hosted server',
    AppLanguage.es: 'Desactivar el modo local y usar el servidor alojado',
    AppLanguage.ca: 'Desactiva el mode local i utilitza el servidor allotjat',
  });

  static const deviceRegion = Translation({AppLanguage.en: 'Device region', AppLanguage.es: 'Región del dispositivo', AppLanguage.ca: 'Regió del dispositiu'});

  static const useDeviceRegion = Translation({
    AppLanguage.en: 'Use device region',
    AppLanguage.es: 'Usar región del dispositivo',
    AppLanguage.ca: 'Utilitzar la regió del dispositiu',
  });
}
