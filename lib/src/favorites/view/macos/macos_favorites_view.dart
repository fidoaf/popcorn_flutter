import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/favorites/view/macos/macos_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// macOS-native list of the user's favorite media.
class MacosFavoritesView extends StatelessWidget {
  const MacosFavoritesView({super.key, required this.controller, this.onMediaSelected});

  final FavoritesController controller;

  /// Called when a favorite row is tapped (opens the details page).
  final ValueChanged<FavoriteMedia>? onMediaSelected;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final favorites = controller.favorites;
        if (favorites.isEmpty) {
          return Center(child: Text(FavoritesTranslations.emptyList.trOf(context), style: typography.body));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final favorite = favorites[favorites.length - 1 - index];
            final item = favorite.item;
            final year = item.releaseDate?.year;
            final subtitle = year == null ? item.overview : '$year \u00b7 ${item.overview}';
            return GestureDetector(
              onTap: onMediaSelected == null ? null : () => onMediaSelected!(favorite),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _Poster(url: item.posterUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: typography.headline),
                          const SizedBox(height: 2),
                          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: typography.subheadline),
                        ],
                      ),
                    ),
                    MacosFavoriteButton(controller: controller, favorite: favorite),
                  ],
                ),
              ),
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
      return _placeholder(CupertinoIcons.film);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url.toString(),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(CupertinoIcons.photo),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(color: MacosColors.systemGrayColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
      child: MacosIcon(icon, color: MacosColors.systemGrayColor),
    );
  }
}
