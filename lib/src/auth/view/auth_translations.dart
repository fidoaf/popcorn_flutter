import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const email = Translation({AppLanguage.en: 'Email', AppLanguage.es: 'Correo electrónico', AppLanguage.ca: 'Correu electrònic'});

  static const password = Translation({AppLanguage.en: 'Password', AppLanguage.es: 'Contraseña', AppLanguage.ca: 'Contrasenya'});

  static const emailPasswordDivider = Translation({
    AppLanguage.en: 'OR',
    AppLanguage.es: 'O',
    AppLanguage.ca: 'O',
  });

  static const signInWithEmail = Translation({
    AppLanguage.en: 'Sign in',
    AppLanguage.es: 'Iniciar sesión',
    AppLanguage.ca: 'Inicia la sessió',
  });

  static const enterEmail = Translation({
    AppLanguage.en: 'Enter your email',
    AppLanguage.es: 'Introduce tu correo electrónico',
    AppLanguage.ca: 'Introdueix el teu correu electrònic',
  });

  static const invalidEmail = Translation({
    AppLanguage.en: 'Enter a valid email address',
    AppLanguage.es: 'Introduce un correo electrónico válido',
    AppLanguage.ca: 'Introdueix una adreça electrònica vàlida',
  });

  static const enterPassword = Translation({
    AppLanguage.en: 'Enter your password',
    AppLanguage.es: 'Introduce tu contraseña',
    AppLanguage.ca: 'Introdueix la contrasenya',
  });

  static const showPassword = Translation({
    AppLanguage.en: 'Show password',
    AppLanguage.es: 'Mostrar contraseña',
    AppLanguage.ca: 'Mostra la contrasenya',
  });

  static const hidePassword = Translation({
    AppLanguage.en: 'Hide password',
    AppLanguage.es: 'Ocultar contraseña',
    AppLanguage.ca: 'Amaga la contrasenya',
  });

  static const authenticationError = Translation({
    AppLanguage.en: 'Authentication failed. Please try again.',
    AppLanguage.es: 'No se pudo completar la autenticación. Inténtalo de nuevo.',
    AppLanguage.ca: 'No s’ha pogut completar l’autenticació. Torna-ho a provar.',
  });

  static const invalidCredentials = Translation({
    AppLanguage.en: 'Invalid email or password.',
    AppLanguage.es: 'El correo electrónico o la contraseña no son correctos.',
    AppLanguage.ca: 'El correu electrònic o la contrasenya no són correctes.',
  });

  static const signInError = Translation({
    AppLanguage.en: 'Could not sign in. Please try again.',
    AppLanguage.es: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    AppLanguage.ca: 'No s’ha pogut iniciar la sessió. Torna-ho a provar.',
  });

  /// Builds the sign-in error message, appending the underlying cause when the
  /// failure carries a human-readable explanation.
  static String signInErrorFor(BuildContext context, Object error) {
    return _compose(context, _detailOf(error));
  }

  /// Builds the sign-in error message from an already-resolved [detail], such
  /// as the description returned by a failed OAuth web redirect.
  static String signInErrorWithDetail(BuildContext context, String? detail) {
    return _compose(context, detail);
  }

  static String authenticationErrorFor(BuildContext context, Object error) {
    if (error is AuthException && _isInvalidCredentials(error.message)) {
      return invalidCredentials.trOf(context);
    }
    final message = authenticationError.trOf(context);
    return message;
  }

  static bool _isInvalidCredentials(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized == 'invalid login credentials' ||
        normalized == 'invalid credentials' ||
        normalized == 'invalid email or password';
  }

  static String _compose(BuildContext context, String? detail) {
    final message = signInError.trOf(context);
    return detail == null || detail.isEmpty ? message : '$message\n$detail';
  }

  static String? _detailOf(Object error) {
    if (error is AuthException) return error.message;
    return null;
  }

  static const continueAsGuest = Translation({
    AppLanguage.en: 'Continue as guest (debug)',
    AppLanguage.es: 'Continuar como invitado (debug)',
    AppLanguage.ca: 'Continua com a convidat (debug)',
  });

  static const guestName = Translation({AppLanguage.en: 'Guest', AppLanguage.es: 'Invitado', AppLanguage.ca: 'Convidat'});
}
