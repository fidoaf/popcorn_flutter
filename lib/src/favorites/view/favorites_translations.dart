import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized strings used by the favorites views.
class FavoritesTranslations {
  FavoritesTranslations._();

  static const pageTitle = Translation({AppLanguage.en: 'Favorites', AppLanguage.es: 'Favoritos', AppLanguage.ca: 'Preferits'});

  static const emptyList = Translation({
    AppLanguage.en: 'You have no favorites yet.',
    AppLanguage.es: 'Aún no tienes favoritos.',
    AppLanguage.ca: 'Encara no tens preferits.',
  });

  static const addToFavorites = Translation({AppLanguage.en: 'Add to favorites', AppLanguage.es: 'Añadir a favoritos', AppLanguage.ca: 'Afegeix a preferits'});

  static const removeFromFavorites = Translation({
    AppLanguage.en: 'Remove from favorites',
    AppLanguage.es: 'Quitar de favoritos',
    AppLanguage.ca: 'Treu de preferits',
  });
}
