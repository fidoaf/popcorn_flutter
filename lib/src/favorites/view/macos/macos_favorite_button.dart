import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// macOS heart button that toggles [favorite] in the [controller].
class MacosFavoriteButton extends StatelessWidget {
  const MacosFavoriteButton({super.key, required this.controller, required this.favorite, this.iconSize = 20});

  final FavoritesController controller;
  final FavoriteMedia favorite;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isFavorite = controller.isFavorite(favorite.type, favorite.item.id);
        return MacosTooltip(
          message: (isFavorite ? FavoritesTranslations.removeFromFavorites : FavoritesTranslations.addToFavorites).trOf(context),
          child: MacosIconButton(
            icon: MacosIcon(
              isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              size: iconSize,
              color: isFavorite ? MacosColors.systemRedColor : null,
            ),
            onPressed: () => controller.toggle(favorite),
          ),
        );
      },
    );
  }
}
