import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/material/material_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_view_mixin.dart';
import 'package:popcorn_flutter/src/search/view/pointer_capability.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Material (Android) UI for searching movies and TV series, driven by a [MediaSearchController].
class MaterialMediaSearchView extends StatefulWidget {
  const MaterialMediaSearchView({
    super.key,
    required this.controller,
    this.onMediaSelected,
    this.onMediaPlay,
    this.favoritesController,
    this.enableDpadFocus = false,
    this.initialQuery,
    this.initialMediaType,
  });

  final MediaSearchController controller;

  /// Drives the per-result favorite toggle. When `null`, no favorite button is shown.
  final FavoritesController? favoritesController;

  /// Called when a result row is tapped (opens the details page).
  final ValueChanged<MediaItem>? onMediaSelected;

  /// Called when a result's play button is tapped (goes straight to the player).
  final ValueChanged<MediaItem>? onMediaPlay;

  /// Query to prefill and run on first show, for opening search via a deep link.
  final String? initialQuery;

  /// Catalogue to select before running [initialQuery].
  final MediaType? initialMediaType;

  /// When `true`, results autofocus the first tile and draw a prominent focus
  /// highlight for D-pad/remote navigation (Fire TV). Defaults to `false` so
  /// the touch UI stays clean with no persistent focus decoration.
  final bool enableDpadFocus;

  @override
  State<MaterialMediaSearchView> createState() => _MaterialMediaSearchViewState();
}

class _MaterialMediaSearchViewState extends State<MaterialMediaSearchView> with MediaSearchViewMixin {
  @override
  MediaSearchController get searchController => widget.controller;

  @override
  ValueChanged<MediaItem>? get onMediaSelected => widget.onMediaSelected;

  @override
  ValueChanged<MediaItem>? get onMediaPlay => widget.onMediaPlay;

  @override
  String? get initialQuery => widget.initialQuery;

  @override
  MediaType? get initialMediaType => widget.initialMediaType;

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
  Widget buildIdleHint(BuildContext context) => Center(child: Text(SearchTranslations.idleHint.trOf(context)));

  @override
  Widget buildLoading(BuildContext context) => const Center(child: CircularProgressIndicator());

  @override
  Widget buildError(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
          const SizedBox(height: 8),
          Text(SearchTranslations.errorTitle.trOf(context), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  @override
  Widget buildEmptyResults(BuildContext context) => Center(child: Text(SearchTranslations.emptyResults.trOf(context)));

  @override
  Widget buildResultItem(BuildContext context, MediaItem item, int index) => _MediaResultTile(
    item: item,
    onTap: onMediaSelected,
    onPlay: onMediaPlay,
    favoritesController: widget.favoritesController,
    mediaType: widget.controller.mediaType,
    dpadFocus: widget.enableDpadFocus,
    autofocus: widget.enableDpadFocus && index == 0,
  );

  @override
  Widget buildTrendingHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(SearchTranslations.trendingTitle.trOf(context), style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => submitSearch(),
            decoration: InputDecoration(
              hintText: SearchTranslations.searchPlaceholder.trOf(context),
              border: const OutlineInputBorder(),
              prefixIcon: hasQuery ? IconButton(icon: const Icon(Icons.clear), onPressed: clearSearch) : const Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => SegmentedButton<MediaType>(
              segments: [
                ButtonSegment(value: MediaType.movie, icon: const Icon(Icons.movie_outlined), label: Text(SearchTranslations.mediaMovies.trOf(context))),
                ButtonSegment(value: MediaType.tv, icon: const Icon(Icons.tv_outlined), label: Text(SearchTranslations.mediaTvSeries.trOf(context))),
              ],
              selected: {widget.controller.mediaType},
              onSelectionChanged: (selection) => widget.controller.setMediaType(selection.first),
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
  const _MediaResultTile({
    required this.item,
    this.onTap,
    this.onPlay,
    this.favoritesController,
    required this.mediaType,
    this.autofocus = false,
    this.dpadFocus = false,
  });

  final MediaItem item;
  final ValueChanged<MediaItem>? onTap;
  final ValueChanged<MediaItem>? onPlay;
  final FavoritesController? favoritesController;
  final MediaType mediaType;
  final bool autofocus;
  final bool dpadFocus;

  @override
  State<_MediaResultTile> createState() => _MediaResultTileState();
}

class _MediaResultTileState extends State<_MediaResultTile> {
  bool _focused = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final year = item.releaseDate?.year;

    final tile = ListTile(
      autofocus: widget.autofocus,
      // Roomier rows on TV so posters/text aren't tiny from across the room.
      contentPadding: widget.dpadFocus ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12) : null,
      onFocusChange: widget.dpadFocus ? (hasFocus) => setState(() => _focused = hasFocus) : null,
      leading: _Poster(url: item.posterUrl, large: widget.dpadFocus),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${year ?? SearchTranslations.tba.trOf(context)} · ${item.overview}', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: _buildTrailing(context),
      onTap: widget.onTap == null ? null : () => widget.onTap!(item),
    );

    // On touch devices the play button is always visible, so no hover tracking
    // is needed; on desktop reveal it while the pointer is over the row.
    final decorated = widget.dpadFocus ? _buildDpadDecoration(context, tile) : tile;
    if (isTouchPrimaryPlatform) return decorated;
    return MouseRegion(onEnter: (_) => setState(() => _hovering = true), onExit: (_) => setState(() => _hovering = false), child: decorated);
  }

  /// Builds the trailing area with the rating and, when appropriate, a play
  /// button. The play button is always shown on touch devices and only while
  /// hovering on desktop.
  Widget? _buildTrailing(BuildContext context) {
    final rating = widget.item.voteAverage;
    final showPlay = isTouchPrimaryPlatform || _hovering;
    final iconSize = widget.dpadFocus ? 28.0 : 18.0;

    final children = <Widget>[
      if (rating != null) ...[Icon(Icons.star, size: iconSize), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))],
      if (widget.favoritesController != null) ...[
        const SizedBox(width: 4),
        MaterialFavoriteButton(
          controller: widget.favoritesController!,
          favorite: FavoriteMedia(item: widget.item, type: widget.mediaType),
          iconSize: widget.dpadFocus ? 28 : 22,
        ),
      ],
      if (showPlay && widget.onPlay != null && widget.item.isReleased) ...[
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.play_circle_fill),
          iconSize: widget.dpadFocus ? 36 : 28,
          tooltip: SearchTranslations.playButton.trOf(context),
          onPressed: () => widget.onPlay!(widget.item),
        ),
      ],
    ];

    if (children.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Wraps [tile] with a prominent border/background when focused so the
  /// selection is clearly visible from across the room when navigating with a
  /// D-pad.
  Widget _buildDpadDecoration(BuildContext context, Widget tile) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _focused ? colorScheme.primary.withValues(alpha: 0.22) : Colors.transparent,
        border: Border.all(color: _focused ? colorScheme.primary : Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: tile,
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url, this.large = false});

  final Uri? url;

  /// Larger poster for the 10-foot TV experience.
  final bool large;

  double get _width => large ? 80 : 46;
  double get _height => large ? 120 : 69;

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
      child: Icon(icon),
    );
  }
}
