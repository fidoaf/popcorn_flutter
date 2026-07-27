import 'package:flutter/cupertino.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Cupertino heart button that toggles [favorite] in the [controller].
class CupertinoFavoriteButton extends StatelessWidget {
  const CupertinoFavoriteButton({super.key, required this.controller, required this.favorite, this.iconSize = 24});

  final FavoritesController controller;
  final FavoriteMedia favorite;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isFavorite = controller.isFavorite(favorite.type, favorite.item.id);
        return CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => controller.toggle(favorite),
          child: Semantics(
            label: (isFavorite ? FavoritesTranslations.removeFromFavorites : FavoritesTranslations.addToFavorites).trOf(context),
            child: Icon(isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, size: iconSize, color: isFavorite ? CupertinoColors.systemRed : null),
          ),
        );
      },
    );
  }
}
