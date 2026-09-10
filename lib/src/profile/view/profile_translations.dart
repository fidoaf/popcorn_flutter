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
}
