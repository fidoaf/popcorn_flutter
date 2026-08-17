import 'package:flutter/cupertino.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/cupertino/cupertino_favorite_button.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/locale/view/locale_formatting.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_view_mixin.dart';
import 'package:popcorn_flutter/src/search/view/pointer_capability.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Cupertino (macOS / iOS) UI for searching movies and TV series, driven by a [MediaSearchController].
class CupertinoMediaSearchView extends StatefulWidget {
  const CupertinoMediaSearchView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay, this.favoritesController});

  final MediaSearchController controller;

  /// Drives the per-result favorite toggle. When `null`, no favorite button is shown.
  final FavoritesController? favoritesController;

  /// Called when a result row is tapped (opens the details page).
  final ValueChanged<MediaItem>? onMediaSelected;

  /// Called when a result's play button is tapped (goes straight to the player).
  final ValueChanged<MediaItem>? onMediaPlay;

  @override
  State<CupertinoMediaSearchView> createState() => _CupertinoMediaSearchViewState();
}

class _CupertinoMediaSearchViewState extends State<CupertinoMediaSearchView> with MediaSearchViewMixin {
  @override
  MediaSearchController get searchController => widget.controller;

  @override
  ValueChanged<MediaItem>? get onMediaSelected => widget.onMediaSelected;

  @override
  ValueChanged<MediaItem>? get onMediaPlay => widget.onMediaPlay;

  @override
  EdgeInsets? get resultListPadding => const EdgeInsets.symmetric(horizontal: 8, vertical: 8);

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
  Widget buildIdleHint(BuildContext context) =>
      Center(child: Text(SearchTranslations.idleHint.trOf(context), style: CupertinoTheme.of(context).textTheme.textStyle));

  @override
  Widget buildLoading(BuildContext context) => const Center(child: CupertinoActivityIndicator());

  @override
  Widget buildError(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, color: CupertinoColors.destructiveRed, size: 40),
          const SizedBox(height: 8),
          Text(SearchTranslations.errorTitle.trOf(context), style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: CupertinoTheme.of(context).textTheme.textStyle),
        ],
      ),
    ),
  );

  @override
  Widget buildEmptyResults(BuildContext context) =>
      Center(child: Text(SearchTranslations.emptyResults.trOf(context), style: CupertinoTheme.of(context).textTheme.textStyle));

  @override
  Widget buildResultItem(BuildContext context, MediaItem item, int index) => _MediaResultTile(
    item: item,
    onTap: onMediaSelected,
    onPlay: onMediaPlay,
    favoritesController: widget.favoritesController,
    mediaType: widget.controller.mediaType,
  );

  @override
  Widget buildTrendingHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(SearchTranslations.trendingTitle.trOf(context), style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CupertinoSearchTextField(
            controller: queryController,
            placeholder: SearchTranslations.searchPlaceholder.trOf(context),
            onSubmitted: (_) => submitSearch(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => CupertinoSegmentedControl<MediaType>(
              groupValue: widget.controller.mediaType,
              onValueChanged: (type) => widget.controller.setMediaType(type),
              children: {
                MediaType.movie: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [const Icon(CupertinoIcons.film, size: 16), const SizedBox(width: 6), Text(SearchTranslations.mediaMovies.trOf(context))],
                  ),
                ),
                MediaType.tv: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [const Icon(CupertinoIcons.tv, size: 16), const SizedBox(width: 6), Text(SearchTranslations.mediaTvSeries.trOf(context))],
                  ),
                ),
              },
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
    final subtitle = '${year ?? SearchTranslations.tba.trOf(context)} \u00b7 ${item.overview}';
    final rating = item.voteAverage;
    final showPlay = isTouchPrimaryPlatform || _hovering;

    final tile = GestureDetector(
      onTap: widget.onTap == null ? null : () => widget.onTap!(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Poster(url: item.posterUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle),
                ],
              ),
            ),
            if (rating != null) ...[
              const Icon(CupertinoIcons.star_fill, size: 14, color: CupertinoColors.systemYellow),
              const SizedBox(width: 4),
              Text(context.formatDecimal(rating), style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle),
            ],
            if (widget.favoritesController != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: CupertinoFavoriteButton(
                  controller: widget.favoritesController!,
                  favorite: FavoriteMedia(item: item, type: widget.mediaType),
                  iconSize: 22,
                ),
              ),
            if (showPlay && widget.onPlay != null && item.isReleased)
              CupertinoButton(
                padding: const EdgeInsets.only(left: 8),
                minimumSize: Size.zero,
                onPressed: () => widget.onPlay!(item),
                child: const Icon(CupertinoIcons.play_circle_fill, size: 28),
              ),
          ],
        ),
      ),
    );

    if (isTouchPrimaryPlatform) return tile;
    return MouseRegion(onEnter: (_) => setState(() => _hovering = true), onExit: (_) => setState(() => _hovering = false), child: tile);
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
      decoration: BoxDecoration(color: CupertinoColors.systemGrey5, borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, color: CupertinoColors.systemGrey),
    );
  }
}
