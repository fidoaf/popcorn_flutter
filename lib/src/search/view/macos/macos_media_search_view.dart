import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/macos/macos_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_view_mixin.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// macOS-native UI for searching movies and TV series, driven by a [MediaSearchController].
///
/// Uses `macos_ui` widgets for a proper desktop macOS look.
class MacosMediaSearchView extends StatefulWidget {
  const MacosMediaSearchView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay, this.favoritesController});

  final MediaSearchController controller;

  /// Drives the per-result favorite toggle. When `null`, no favorite button is shown.
  final FavoritesController? favoritesController;

  /// Called when a result row is tapped (opens the details page).
  final ValueChanged<MediaItem>? onMediaSelected;

  /// Called when a result's play button is tapped (goes straight to the player).
  final ValueChanged<MediaItem>? onMediaPlay;

  @override
  State<MacosMediaSearchView> createState() => _MacosMediaSearchViewState();
}

class _MacosMediaSearchViewState extends State<MacosMediaSearchView> with MediaSearchViewMixin {
  @override
  MediaSearchController get searchController => widget.controller;

  @override
  ValueChanged<MediaItem>? get onMediaSelected => widget.onMediaSelected;

  @override
  ValueChanged<MediaItem>? get onMediaPlay => widget.onMediaPlay;

  @override
  EdgeInsets? get resultListPadding => const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  @override
  void initState() {
    super.initState();
    initSearchView();
  }

  @override
  void dispose() {
    disposeSearchView();
    super.dispose();
  }

  @override
  Widget buildIdleHint(BuildContext context) => Center(child: Text(SearchTranslations.idleHint.trOf(context), style: MacosTheme.of(context).typography.body));

  @override
  Widget buildLoading(BuildContext context) => const Center(child: ProgressCircle());

  @override
  Widget buildError(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MacosIcon(CupertinoIcons.exclamationmark_triangle, size: 40, color: MacosColors.systemRedColor),
          const SizedBox(height: 8),
          Text(SearchTranslations.errorTitle.trOf(context), style: MacosTheme.of(context).typography.headline),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: MacosTheme.of(context).typography.body),
        ],
      ),
    ),
  );

  @override
  Widget buildEmptyResults(BuildContext context) =>
      Center(child: Text(SearchTranslations.emptyResults.trOf(context), style: MacosTheme.of(context).typography.body));

  @override
  Widget buildResultItem(BuildContext context, MediaItem item, int index) =>
      _MediaResultTile(item: item, onTap: onMediaSelected, onPlay: onMediaPlay, favoritesController: widget.favoritesController, mediaType: widget.controller.mediaType);

  @override
  Widget buildTrendingHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Text(SearchTranslations.trendingTitle.trOf(context), style: MacosTheme.of(context).typography.headline),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: MacosSearchField(
            controller: queryController,
            placeholder: SearchTranslations.searchPlaceholder.trOf(context),
            onChanged: (_) => submitSearch(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => Row(
              children: [
                _SegmentButton(
                  icon: CupertinoIcons.film,
                  label: SearchTranslations.mediaMovies.trOf(context),
                  selected: widget.controller.mediaType == MediaType.movie,
                  onPressed: () => widget.controller.setMediaType(MediaType.movie),
                ),
                const SizedBox(width: 8),
                _SegmentButton(
                  icon: CupertinoIcons.tv,
                  label: SearchTranslations.mediaTvSeries.trOf(context),
                  selected: widget.controller.mediaType == MediaType.tv,
                  onPressed: () => widget.controller.setMediaType(MediaType.tv),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => buildBody(context)),
        ),
      ],
    );
  }
}

/// A macOS-style toggle button used for the media type selector.
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.icon, required this.label, required this.selected, required this.onPressed});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PushButton(
      controlSize: ControlSize.regular,
      secondary: !selected,
      onPressed: onPressed,
      child: Row(mainAxisSize: MainAxisSize.min, children: [MacosIcon(icon, size: 14), const SizedBox(width: 6), Text(label)]),
    );
  }
}

class _MediaResultTile extends StatefulWidget {
  const _MediaResultTile({required this.item, this.onTap, this.onPlay, this.favoritesController, required this.mediaType});

  final MediaItem item;
  final ValueChanged<MediaItem>? onTap;
  final ValueChanged<MediaItem>? onPlay;
  final FavoritesController? favoritesController;
  final MediaType mediaType;

  @override
  State<_MediaResultTile> createState() => _MediaResultTileState();
}

class _MediaResultTileState extends State<_MediaResultTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final year = item.releaseDate?.year;
    final subtitle = year == null ? item.overview : '$year \u00b7 ${item.overview}';
    final rating = item.voteAverage;
    final typography = MacosTheme.of(context).typography;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap == null ? null : () => widget.onTap!(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering ? MacosTheme.of(context).primaryColor.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(6),
          ),
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
              if (rating != null) ...[
                const MacosIcon(CupertinoIcons.star_fill, size: 14, color: MacosColors.systemYellowColor),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1), style: typography.subheadline),
              ],
              if (widget.favoritesController != null) ...[
                const SizedBox(width: 8),
                MacosFavoriteButton(controller: widget.favoritesController!, favorite: FavoriteMedia(item: item, type: widget.mediaType)),
              ],
              if (_hovering && widget.onPlay != null) ...[
                const SizedBox(width: 8),
                MacosIconButton(icon: const MacosIcon(CupertinoIcons.play_circle_fill, size: 24), onPressed: () => widget.onPlay!(item)),
              ],
            ],
          ),
        ),
      ),
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
