import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/favorites/view/fluent/fluent_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Fluent (Windows) list of the user's favorite media.
class FluentFavoritesView extends StatelessWidget {
  const FluentFavoritesView({super.key, required this.controller, this.onMediaSelected});

  final FavoritesController controller;

  /// Called when a favorite row is tapped (opens the details page).
  final ValueChanged<FavoriteMedia>? onMediaSelected;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        padding: 16,
        leading: IconButton(icon: const Icon(FluentIcons.back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(FavoritesTranslations.pageTitle.trOf(context)),
      ),
      content: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final favorites = controller.favorites;
          if (favorites.isEmpty) {
            return Center(child: Text(FavoritesTranslations.emptyList.trOf(context)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[favorites.length - 1 - index];
              final item = favorite.item;
              final year = item.releaseDate?.year;
              final subtitle = year == null ? item.overview : '$year \u00b7 ${item.overview}';
              return ListTile.selectable(
                leading: _Poster(url: item.posterUrl),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: FluentFavoriteButton(controller: controller, favorite: favorite),
                selected: false,
                onSelectionChange: onMediaSelected == null ? null : (_) => onMediaSelected!(favorite),
              );
            },
          );
        },
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 40;
  static const double _height = 60;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(context, FluentIcons.video);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url.toString(),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, FluentIcons.error),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(color: FluentTheme.of(context).resources.subtleFillColorSecondary, borderRadius: BorderRadius.circular(4)),
      child: Icon(icon),
    );
  }
}
