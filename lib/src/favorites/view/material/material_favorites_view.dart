import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/favorites/view/material/material_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Material (Android / web) list of the user's favorite media.
class MaterialFavoritesView extends StatelessWidget {
  const MaterialFavoritesView({super.key, required this.controller, this.onMediaSelected});

  final FavoritesController controller;

  /// Called when a favorite row is tapped (opens the details page).
  final ValueChanged<FavoriteMedia>? onMediaSelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final favorites = controller.favorites;
        if (favorites.isEmpty) {
          return Center(child: Text(FavoritesTranslations.emptyList.trOf(context)));
        }
        return ListView.builder(
          itemCount: favorites.length,
          // Show the most recently added favorite first.
          itemBuilder: (context, index) {
            final favorite = favorites[favorites.length - 1 - index];
            final item = favorite.item;
            final year = item.releaseDate?.year;
            return ListTile(
              leading: _Poster(url: item.posterUrl),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(year == null ? item.overview : '$year · ${item.overview}', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: MaterialFavoriteButton(controller: controller, favorite: favorite),
              onTap: onMediaSelected == null ? null : () => onMediaSelected!(favorite),
            );
          },
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 46;
  static const double _height = 69;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(context, Icons.movie_outlined);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url.toString(),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, Icons.broken_image_outlined),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
