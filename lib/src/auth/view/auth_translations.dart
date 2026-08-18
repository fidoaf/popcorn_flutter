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

  static const signInError = Translation({
    AppLanguage.en: 'Could not sign in. Please try again.',
    AppLanguage.es: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    AppLanguage.ca: 'No s’ha pogut iniciar la sessió. Torna-ho a provar.',
  });

  /// Builds the sign-in error message, appending the underlying cause when the
  /// failure carries a human-readable explanation.
  static String signInErrorFor(BuildContext context, Object error) {
    final message = signInError.trOf(context);
    final detail = _detailOf(error);
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
}
