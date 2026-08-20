import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_translations.dart';
import 'package:popcorn_flutter/src/favorites/view/fluent/fluent_favorite_button.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_translations.dart';
import 'package:popcorn_flutter/src/locale/view/locale_formatting.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_view_mixin.dart';
import 'package:popcorn_flutter/src/search/view/pointer_capability.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Fluent (Windows) UI for searching movies and TV series, driven by a [MediaSearchController].
class FluentMediaSearchView extends StatefulWidget {
  const FluentMediaSearchView({
    super.key,
    required this.controller,
    this.onMediaSelected,
    this.onMediaPlay,
    this.favoritesController,
    this.onOpenFavorites,
    this.onOpenContinueWatching,
    this.initialQuery,
    this.initialMediaType,
    this.authController,
  });

  final MediaSearchController controller;

  /// Drives the page title greeting (avatar + first name). When `null`, the
  /// static "Search" title is shown instead.
  final AuthController? authController;

  /// Drives the per-result favorite toggle. When `null`, no favorite button is shown.
  final FavoritesController? favoritesController;

  /// Called when the favorites command bar button is tapped. When `null`, no
  /// favorites button is shown in the header.
  final VoidCallback? onOpenFavorites;

  /// Called when the continue-watching command bar button is tapped. When
  /// `null`, no continue-watching button is shown in the header.
  final VoidCallback? onOpenContinueWatching;

  /// Called when a result row is tapped (opens the details page).
  final ValueChanged<MediaItem>? onMediaSelected;

  /// Called when a result's play button is tapped (goes straight to the player).
  final ValueChanged<MediaItem>? onMediaPlay;

  /// Query to prefill and run on first show, for opening search via a deep link.
  final String? initialQuery;

  /// Catalogue to select before running [initialQuery].
  final MediaType? initialMediaType;

  @override
  State<FluentMediaSearchView> createState() => _FluentMediaSearchViewState();
}

class _FluentMediaSearchViewState extends State<FluentMediaSearchView> with MediaSearchViewMixin {
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
  Widget buildIdleHint(BuildContext context) => Center(child: Text(SearchTranslations.idleHint.trOf(context)));

  @override
  Widget buildLoading(BuildContext context) => const Center(child: ProgressRing());

  @override
  Widget buildError(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: InfoBar(title: Text(SearchTranslations.errorTitle.trOf(context)), content: Text(message), severity: InfoBarSeverity.error),
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
  );

  @override
  Widget buildTrendingHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
    child: Text(SearchTranslations.trendingTitle.trOf(context), style: FluentTheme.of(context).typography.subtitle),
  );

  @override
  Widget build(BuildContext context) {
    final showLabels = MediaQuery.sizeOf(context).width >= 600;
    return ScaffoldPage(
      header: PageHeader(
        padding: 16,
        title: widget.onOpenFavorites == null && widget.onOpenContinueWatching == null
            ? Text(SearchTranslations.pageTitle.trOf(context))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.onOpenContinueWatching != null)
                    showLabels
                        ? Button(
                            onPressed: widget.onOpenContinueWatching,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [const Icon(FluentIcons.play), const SizedBox(width: 8), Text(WatchHistoryTranslations.pageTitle.trOf(context))],
                            ),
                          )
                        : Tooltip(
                            message: WatchHistoryTranslations.pageTitle.trOf(context),
                            child: IconButton(icon: const Icon(FluentIcons.play), onPressed: widget.onOpenContinueWatching),
                          ),
                  if (widget.onOpenContinueWatching != null && widget.onOpenFavorites != null) const SizedBox(width: 8),
                  if (widget.onOpenFavorites != null)
                    showLabels
                        ? Button(
                            onPressed: widget.onOpenFavorites,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [const Icon(FluentIcons.heart), const SizedBox(width: 8), Text(FavoritesTranslations.pageTitle.trOf(context))],
                            ),
                          )
                        : Tooltip(
                            message: FavoritesTranslations.pageTitle.trOf(context),
                            child: IconButton(icon: const Icon(FluentIcons.heart), onPressed: widget.onOpenFavorites),
                          ),
                ],
              ),
        commandBar: widget.authController == null
            ? null
            : UserIdentityTitle(controller: widget.authController!, fallbackTitle: Text(SearchTranslations.pageTitle.trOf(context))),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextBox(
              controller: queryController,
              placeholder: SearchTranslations.searchPlaceholder.trOf(context),
              onSubmitted: (_) => submitSearch(),
              prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 4), child: Icon(FluentIcons.search)),
              suffix: hasQuery ? IconButton(icon: const Icon(FluentIcons.clear), onPressed: clearSearch) : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => Row(
                children: [
                  ToggleButton(
                    checked: widget.controller.mediaType == MediaType.movie,
                    onChanged: (_) => widget.controller.setMediaType(MediaType.movie),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [const Icon(FluentIcons.my_movies_t_v), const SizedBox(width: 6), Text(SearchTranslations.mediaMovies.trOf(context))],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToggleButton(
                    checked: widget.controller.mediaType == MediaType.tv,
                    onChanged: (_) => widget.controller.setMediaType(MediaType.tv),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [const Icon(FluentIcons.t_v_monitor), const SizedBox(width: 6), Text(SearchTranslations.mediaTvSeries.trOf(context))],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => buildBody(context)),
          ),
        ],
      ),
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

    final tile = ListTile.selectable(
      leading: _Poster(url: item.posterUrl),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: _buildTrailing(context),
      selected: false,
      onSelectionChange: widget.onTap == null ? null : (_) => widget.onTap!(item),
    );

    // On touch devices the play button stays visible, so hover tracking isn't
    // needed; on desktop reveal it while the pointer is over the row.
    if (isTouchPrimaryPlatform) return tile;
    return MouseRegion(onEnter: (_) => setState(() => _hovering = true), onExit: (_) => setState(() => _hovering = false), child: tile);
  }

  /// Builds the trailing area with the rating and, when appropriate, a play
  /// button. The play button is always shown on touch devices and only while
  /// hovering on desktop.
  Widget? _buildTrailing(BuildContext context) {
    final rating = widget.item.voteAverage;
    final showPlay = isTouchPrimaryPlatform || _hovering;

    final children = <Widget>[
      if (rating != null) ...[const Icon(FluentIcons.favorite_star_fill), const SizedBox(width: 4), Text(context.formatDecimal(rating))],
      if (widget.favoritesController != null) ...[
        const SizedBox(width: 4),
        FluentFavoriteButton(
          controller: widget.favoritesController!,
          favorite: FavoriteMedia(item: widget.item, type: widget.mediaType),
        ),
      ],
      if (showPlay && widget.onPlay != null && widget.item.isReleased) ...[
        const SizedBox(width: 8),
        IconButton(icon: const Icon(FluentIcons.play_solid), onPressed: () => widget.onPlay!(widget.item)),
      ],
    ];

    if (children.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: children);
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
