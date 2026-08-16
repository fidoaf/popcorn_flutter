import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the authentication views.
class AuthTranslations {
  AuthTranslations._();

  static const signInSubtitle = Translation({
    AppLanguage.en: 'Sign in to continue',
    AppLanguage.es: 'Inicia sesión para continuar',
    AppLanguage.ca: 'Inicia la sessió per continuar',
  });

  static const signInWithGoogle = Translation({
    AppLanguage.en: 'Sign in with Google',
    AppLanguage.es: 'Iniciar sesión con Google',
    AppLanguage.ca: 'Inicia la sessió amb Google',
  });

  static const signInError = Translation({
    AppLanguage.en: 'Could not sign in. Please try again.',
    AppLanguage.es: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    AppLanguage.ca: 'No s’ha pogut iniciar la sessió. Torna-ho a provar.',
  });
}
