import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Material heart button that toggles [favorite] in the [controller].
///
/// Rebuilds whenever the favorites change so the filled/outlined state always
/// reflects the persisted set.
class MaterialFavoriteButton extends StatelessWidget {
  const MaterialFavoriteButton({super.key, required this.controller, required this.favorite, this.iconSize = 24});

  final FavoritesController controller;
  final FavoriteMedia favorite;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isFavorite = controller.isFavorite(favorite.type, favorite.item.id);
        return IconButton(
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          iconSize: iconSize,
          color: isFavorite ? Theme.of(context).colorScheme.primary : null,
          tooltip: (isFavorite ? FavoritesTranslations.removeFromFavorites : FavoritesTranslations.addToFavorites).trOf(context),
          onPressed: () => controller.toggle(favorite),
        );
      },
    );
  }
}
