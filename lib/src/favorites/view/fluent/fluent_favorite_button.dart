import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Fluent heart button that toggles [favorite] in the [controller].
class FluentFavoriteButton extends StatelessWidget {
  const FluentFavoriteButton({super.key, required this.controller, required this.favorite, this.iconSize});

  final FavoritesController controller;
  final FavoriteMedia favorite;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isFavorite = controller.isFavorite(favorite.type, favorite.item.id);
        return Tooltip(
          message: (isFavorite ? FavoritesTranslations.removeFromFavorites : FavoritesTranslations.addToFavorites).trOf(context),
          child: IconButton(
            icon: Icon(isFavorite ? FluentIcons.heart_fill : FluentIcons.heart, size: iconSize, color: isFavorite ? Colors.red : null),
            onPressed: () => controller.toggle(favorite),
          ),
        );
      },
    );
  }
}
