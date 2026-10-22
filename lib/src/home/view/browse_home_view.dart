import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/app/view/app_version_footer.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/home/view/home_feed_controller.dart';
import 'package:popcorn_flutter/src/home/view/home_translations.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_logo.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_country.dart';
import 'package:popcorn_flutter/src/locale/view/locale_formatting.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/radio/radio_controller.dart';
import 'package:popcorn_flutter/src/radio/radio_logo.dart';
import 'package:popcorn_flutter/src/radio/radio_station.dart';
import 'package:popcorn_flutter/src/radio/radio_translations.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Fixed dark palette so the browse experience looks identical across the
/// Material, Fluent and macOS shells (the browse home is always dark).
abstract final class _Palette {
  static const background = Color(0xFF0F171E);
  static const backgroundTop = Color(0xFF16212B);
  static const surface = Color(0xFF1A242F);
  static const accent = Color(0xFF1FAAE2);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9BA9B4);
  static const focus = Color(0xFFFFFFFF);
}

/// A framework-agnostic, streaming-style home screen: a full-bleed
/// hero banner over horizontally scrolling poster carousels (continue watching,
/// my list, trending movies, trending TV series).
///
/// Content is wrapped in a transparent [Material] and uses a fixed dark palette
/// so the exact same layout renders inside every platform shell (Material,
/// Fluent, macOS) without depending on the surrounding theme.
class BrowseHomeView extends StatefulWidget {
  const BrowseHomeView({
    super.key,
    required this.feedController,
    required this.favoritesController,
    required this.historyController,
    required this.searchController,
    required this.onOpenDetails,
    required this.onPlay,
    required this.onResume,
    this.onSeeAllFavorites,
    this.onSeeAllHistory,
    this.enableDpadFocus = false,
    this.initialQuery,
    this.initialMediaType,
  });

  final HomeFeedController feedController;
  final FavoritesController favoritesController;
  final WatchHistoryController historyController;

  /// Drives the inline search overlay (results, trending, media type).
  final MediaSearchController searchController;

  /// Opens the details page for a catalogue entry.
  final void Function(MediaItem item, MediaType type) onOpenDetails;

  /// Starts playback of a catalogue title.
  final void Function(MediaItem item, MediaType type) onPlay;

  /// Resumes playback of a continue-watching entry (with its season/episode).
  final void Function(WatchHistoryEntry entry) onResume;

  /// Optional "see all" targets for the corresponding rows.
  final VoidCallback? onSeeAllFavorites;
  final VoidCallback? onSeeAllHistory;

  /// Autofocuses the hero action and draws focus highlights for D-pad/remote
  /// navigation (Fire TV).
  final bool enableDpadFocus;

  /// When non-empty, opens the search overlay on first build pre-filled with
  /// this query (e.g. from a `/search/{type}?q=` deep link).
  final String? initialQuery;

  /// The media type to search when [initialQuery] is provided.
  final MediaType? initialMediaType;

  @override
  State<BrowseHomeView> createState() => _BrowseHomeViewState();
}

class _BrowseHomeViewState extends State<BrowseHomeView> {
  bool _searchActive = false;
  late final LiveTvController _liveTvController;
  late final RadioController _radioController;

  @override
  void initState() {
    super.initState();
    _liveTvController = LiveTvController()..load();
    _radioController = RadioController()..load();
    widget.searchController.addListener(_syncSearchUrl);
    final query = widget.initialQuery?.trim() ?? '';
    if (query.isEmpty) {
      widget.searchController.clear();
      return;
    }
    // Seed the controller synchronously so the overlay's field shows the query.
    _searchActive = true;
    final type = widget.initialMediaType;
    if (type != null) widget.searchController.setMediaType(type);
    widget.searchController.search(query);
  }

  void _syncSearchUrl() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      final uri = router.routeInformationProvider.value.uri;
      if (uri.path != AppRoutes.home && !uri.path.startsWith('/search/')) return;
      final query = widget.searchController.query;
      final type = widget.searchController.mediaType;
      final location = uri.path == AppRoutes.home || query.isEmpty ? AppRoutes.homeSearch(query, type: type) : AppRoutes.search(query, type: type);
      if (uri.toString() != location) Router.neglect(context, () => router.go(location));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_syncSearchUrl);
    _liveTvController.dispose();
    _radioController.dispose();
    super.dispose();
  }

  void _openSearch() {
    if (!_searchActive) setState(() => _searchActive = true);
  }

  void _closeSearch() {
    setState(() => _searchActive = false);
    widget.searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Palette.backgroundTop, _Palette.background],
            stops: [0.0, 0.4],
          ),
        ),
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([widget.feedController, widget.favoritesController, widget.historyController]),
              builder: (context, _) => _buildBrowse(context),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: _searchActive ? 0 : null,
              child: HomeSearchOverlay(
                active: _searchActive,
                onActivate: _openSearch,
                controller: widget.searchController,
                favoritesController: widget.favoritesController,
                enableDpadFocus: widget.enableDpadFocus,
                onClose: _closeSearch,
                onOpenDetails: (item) => widget.onOpenDetails(item, widget.searchController.mediaType),
                onPlay: (item) => widget.onPlay(item, widget.searchController.mediaType),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowse(BuildContext context) {
    final feedController = widget.feedController;
    if (feedController.isLoading) {
      return const _BrowseSkeleton();
    }

    if (feedController.hasError) {
      return _ErrorState(onRetry: feedController.load);
    }

    final history = widget.historyController.entries;
    final favorites = widget.favoritesController.favorites;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          if (feedController.featured != null)
            SliverToBoxAdapter(
              child: _HeroBanner(
                item: feedController.featured!,
                autofocus: widget.enableDpadFocus,
                onPlay: () => widget.onPlay(feedController.featured!, feedController.featuredType),
                onDetails: () => widget.onOpenDetails(feedController.featured!, feedController.featuredType),
              ),
            ),
          if (history.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.continueWatching.trOf(context),
              onSeeAll: widget.onSeeAllHistory,
              seeAllLabel: HomeTranslations.seeAll.trOf(context),
              itemCount: history.length,
              cardBuilder: (context, index) {
                final entry = history[index];
                return _PosterCard(
                  item: entry.item,
                  mediaType: entry.type,
                  favoritesController: widget.favoritesController,
                  badgeLabel: _posterBadgeLabel(entry.item, entry.type, context),
                  showResumeBadge: true,
                  onTap: () => widget.onOpenDetails(entry.item, entry.type),
                  onResume: () => widget.onResume(entry),
                );
              },
            ),
          if (favorites.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.myList.trOf(context),
              onSeeAll: widget.onSeeAllFavorites,
              seeAllLabel: HomeTranslations.seeAll.trOf(context),
              itemCount: favorites.length,
              cardBuilder: (context, index) {
                final FavoriteMedia favorite = favorites[index];
                return _PosterCard(
                  item: favorite.item,
                  mediaType: favorite.type,
                  favoritesController: widget.favoritesController,
                  badgeLabel: _posterBadgeLabel(favorite.item, favorite.type, context),
                  onTap: () => widget.onOpenDetails(favorite.item, favorite.type),
                );
              },
            ),
          if (feedController.trendingMovies.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.trendingMovies.trOf(context),
              itemCount: feedController.trendingMovies.length,
              cardBuilder: (context, index) {
                final item = feedController.trendingMovies[index];
                return _PosterCard(
                  item: item,
                  mediaType: MediaType.movie,
                  favoritesController: widget.favoritesController,
                  badgeLabel: _posterBadgeLabel(item, MediaType.movie, context),
                  onTap: () => widget.onOpenDetails(item, MediaType.movie),
                );
              },
            ),
          if (feedController.trendingTv.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.trendingTv.trOf(context),
              itemCount: feedController.trendingTv.length,
              cardBuilder: (context, index) {
                final item = feedController.trendingTv[index];
                return _PosterCard(
                  item: item,
                  mediaType: MediaType.tv,
                  favoritesController: widget.favoritesController,
                  badgeLabel: _posterBadgeLabel(item, MediaType.tv, context),
                  onTap: () => widget.onOpenDetails(item, MediaType.tv),
                );
              },
            ),
          if (feedController.trendingTrailers.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.trendingTrailers.trOf(context),
              itemCount: feedController.trendingTrailers.length,
              cardHeight: 222,
              cardBuilder: (context, index) {
                final trailer = feedController.trendingTrailers[index];
                return _TrailerCard(
                  item: trailer.item,
                  video: trailer.video,
                  onDetails: () => widget.onOpenDetails(trailer.item, trailer.type),
                  onPlay: () => context.push(AppRoutes.trailer, extra: trailer.video),
                );
              },
            ),
          SliverToBoxAdapter(child: LiveTvSection(controller: _liveTvController)),
          SliverToBoxAdapter(child: RadioSection(controller: _radioController)),
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 20), child: AppVersionFooter()),
          ),
        ],
      ),
    );
  }
}

/// A persistent search input that expands to show the selector and results.
class HomeSearchOverlay extends StatefulWidget {
  const HomeSearchOverlay({
    super.key,
    required this.active,
    required this.onActivate,
    required this.controller,
    required this.favoritesController,
    required this.onClose,
    required this.onOpenDetails,
    required this.onPlay,
    this.enableDpadFocus = false,
    this.liveTvController,
    this.radioController,
  });

  final bool active;
  final VoidCallback onActivate;
  final MediaSearchController controller;
  final FavoritesController favoritesController;
  final VoidCallback onClose;
  final ValueChanged<MediaItem> onOpenDetails;
  final ValueChanged<MediaItem> onPlay;
  final bool enableDpadFocus;
  final LiveTvController? liveTvController;
  final RadioController? radioController;

  @override
  State<HomeSearchOverlay> createState() => _SearchOverlayState();
}

enum _SearchType { movie, tv, liveTv, radio }

class _SearchOverlayState extends State<HomeSearchOverlay> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  late _SearchType _searchType;
  late final LiveTvController _liveSearch;
  late final RadioController _radioSearch;

  @override
  void initState() {
    super.initState();
    _liveSearch = widget.liveTvController ?? LiveTvController();
    _radioSearch = widget.radioController ?? RadioController();
    _searchType = widget.controller.mediaType == MediaType.tv ? _SearchType.tv : _SearchType.movie;
    _queryController.text = widget.controller.query;
    _focusNode.addListener(_onFocusChanged);
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !widget.active) widget.onActivate();
  }

  @override
  void didUpdateWidget(covariant HomeSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _debounce?.cancel();
      _focusNode.unfocus();
      _queryController.clear();
      _searchType = widget.controller.mediaType == MediaType.tv ? _SearchType.tv : _SearchType.movie;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.liveTvController == null) _liveSearch.dispose();
    if (widget.radioController == null) _radioSearch.dispose();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Debounce keystrokes so we don't fire a request on every character.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  void _search(String query) {
    if (_searchType == _SearchType.radio) {
      _radioSearch.search(query);
    } else if (_searchType == _SearchType.liveTv) {
      _liveSearch.search(query);
    } else {
      widget.controller.search(query);
    }
  }

  void _selectType(_SearchType type) {
    _debounce?.cancel();
    setState(() => _searchType = type);
    if (type == _SearchType.liveTv || type == _SearchType.radio) {
      widget.controller.clear();
    } else {
      widget.controller.setMediaType(type == _SearchType.tv ? MediaType.tv : MediaType.movie);
    }
    _search(_queryController.text);
  }

  void _submit() {
    _debounce?.cancel();
    _search(_queryController.text);
  }

  void _clear() {
    _debounce?.cancel();
    _queryController.clear();
    if (_searchType == _SearchType.radio) {
      _radioSearch.search('');
    } else if (_searchType == _SearchType.liveTv) {
      _liveSearch.search('');
    } else {
      widget.controller.clear();
    }
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.active) widget.onClose();
      },
      child: ColoredBox(
        color: widget.active ? _Palette.background : Colors.transparent,
        child: SafeArea(
          bottom: widget.active,
          child: Column(
            mainAxisSize: widget.active ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Padding(
                padding: widget.active ? const EdgeInsets.fromLTRB(8, 8, 12, 8) : const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    if (widget.active)
                      _Pressable(
                        onTap: widget.onClose,
                        borderRadius: 20,
                        builder: (focused, hovered) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
                          ),
                          child: const Icon(Icons.arrow_back, color: _Palette.textPrimary, size: 22),
                        ),
                      ),
                    if (widget.active) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: _Palette.surface, borderRadius: BorderRadius.circular(22)),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: _Palette.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _queryController,
                                focusNode: _focusNode,
                                autofocus: false,
                                onTap: widget.onActivate,
                                onChanged: _onChanged,
                                onSubmitted: (_) => _submit(),
                                textInputAction: TextInputAction.search,
                                cursorColor: _Palette.accent,
                                style: const TextStyle(color: _Palette.textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: widget.active ? SearchTranslations.searchPlaceholder.trOf(context) : HomeTranslations.search.trOf(context),
                                  hintStyle: const TextStyle(color: _Palette.textSecondary, fontSize: 15),
                                ),
                              ),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _queryController,
                              builder: (context, value, _) => value.text.isEmpty
                                  ? const SizedBox.shrink()
                                  : _Pressable(
                                      onTap: _clear,
                                      borderRadius: 16,
                                      builder: (focused, hovered) =>
                                          Icon(Icons.close, color: focused ? _Palette.textPrimary : _Palette.textSecondary, size: 20),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.active)
                ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => _MediaTypeToggle(
                    selectedType: switch (_searchType) {
                      _SearchType.movie || _SearchType.tv => widget.controller.mediaType == MediaType.tv ? _SearchType.tv : _SearchType.movie,
                      _ => _searchType,
                    },
                    onSelected: _selectType,
                  ),
                ),
              if (widget.active)
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([widget.controller, _liveSearch, _radioSearch]),
                    builder: (context, _) => switch (_searchType) {
                      _SearchType.radio => _buildRadioResults(context),
                      _SearchType.liveTv => _buildLiveResults(context),
                      _ => _buildResults(context),
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final state = widget.controller.state;
    return switch (state) {
      MediaSearchIdle(:final trendingItems) when trendingItems.isNotEmpty => _grid(
        context,
        trendingItems,
        header: SearchTranslations.trendingTitle.trOf(context),
      ),
      MediaSearchIdle() => _message(SearchTranslations.idleHint.trOf(context)),
      MediaSearchLoading() => const _SearchGridSkeleton(),
      MediaSearchFailure(:final message) => _message(message),
      MediaSearchSuccess(:final items) when items.isEmpty => _message(SearchTranslations.emptyResults.trOf(context)),
      MediaSearchSuccess(:final items) => _grid(context, items),
    };
  }

  Widget _buildLiveResults(BuildContext context) {
    if (_liveSearch.isLoading) return const Center(child: CircularProgressIndicator(color: _Palette.accent));
    if (_liveSearch.hasError) {
      return _LiveTvMessage(
        text: HomeTranslations.liveTvUnavailable.trOf(context),
        actionLabel: HomeTranslations.retry.trOf(context),
        onAction: () => _search(_queryController.text),
      );
    }
    if (_liveSearch.channels.isEmpty) return _message(SearchTranslations.emptyResults.trOf(context));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 142, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _liveSearch.channels.length,
      itemBuilder: (context, index) => LiveTvChannelCard(channel: _liveSearch.channels[index]),
    );
  }

  Widget _buildRadioResults(BuildContext context) {
    if (_radioSearch.isLoading) return const Center(child: CircularProgressIndicator(color: _Palette.accent));
    if (_radioSearch.hasError) {
      return _LiveTvMessage(
        text: RadioTranslations.unavailable.trOf(context),
        actionLabel: HomeTranslations.retry.trOf(context),
        onAction: () => _search(_queryController.text),
      );
    }
    if (_radioSearch.stations.isEmpty) return _message(SearchTranslations.emptyResults.trOf(context));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 164, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _radioSearch.stations.length,
      itemBuilder: (context, index) => RadioStationCard(station: _radioSearch.stations[index]),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _Palette.textSecondary, fontSize: 15),
      ),
    ),
  );

  Widget _grid(BuildContext context, List<MediaItem> items, {String? header}) {
    return CustomScrollView(
      slivers: [
        if (header != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                header,
                style: const TextStyle(color: _Palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return _SearchResultCard(
                item: item,
                mediaType: widget.controller.mediaType,
                favoritesController: widget.favoritesController,
                badgeLabel: _posterBadgeLabel(item, widget.controller.mediaType, context),
                autofocus: widget.enableDpadFocus && index == 0,
                onTap: () => widget.onOpenDetails(item),
              );
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }
}

/// Content types shown above the search results.
class _MediaTypeToggle extends StatelessWidget {
  const _MediaTypeToggle({required this.selectedType, required this.onSelected});

  final _SearchType selectedType;
  final ValueChanged<_SearchType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _chip(context, _SearchType.movie, SearchTranslations.mediaMovies.trOf(context)),
          _chip(context, _SearchType.tv, SearchTranslations.mediaTvSeries.trOf(context)),
          _chip(context, _SearchType.liveTv, HomeTranslations.liveTv.trOf(context)),
          _chip(context, _SearchType.radio, RadioTranslations.title.trOf(context)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, _SearchType type, String label) {
    final selected = type == selectedType;
    return Semantics(selected: selected, button: true, child: _buildChip(type, label, selected));
  }

  Widget _buildChip(_SearchType type, String label, bool selected) {
    return _Pressable(
      onTap: () => onSelected(type),
      borderRadius: 18,
      builder: (focused, hovered) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _Palette.accent : _Palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? const Color(0xFF06202B) : _Palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A poster + title cell used in the search results grid.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.item,
    required this.mediaType,
    required this.favoritesController,
    required this.onTap,
    this.badgeLabel,
    this.autofocus = false,
  });

  final MediaItem item;
  final MediaType mediaType;
  final FavoritesController favoritesController;
  final VoidCallback onTap;
  final String? badgeLabel;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      autofocus: autofocus,
      borderRadius: 8,
      builder: (focused, hovered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2.5),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item.posterUrl != null
                          ? Image.network(
                              item.posterUrl.toString(),
                              fit: BoxFit.cover,
                              loadingBuilder: _imageSkeletonBuilder,
                              errorBuilder: (context, _, _) => const _PosterPlaceholder(),
                            )
                          : const _PosterPlaceholder(),
                    ),
                  ),
                  if (badgeLabel != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      left: 0,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _PosterBadge(label: badgeLabel!),
                      ),
                    ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: _PosterLikeButton(item: item, mediaType: mediaType, controller: favoritesController),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _Palette.textPrimary, fontSize: 12, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// A compact heart button overlaid on a poster that toggles the item in the
/// user's favorites.
class _PosterLikeButton extends StatelessWidget {
  const _PosterLikeButton({required this.item, required this.mediaType, required this.controller});

  final MediaItem item;
  final MediaType mediaType;
  final FavoritesController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isFavorite = controller.isFavorite(mediaType, item.id);
        return _Pressable(
          onTap: () => controller.toggle(FavoriteMedia(item: item, type: mediaType)),
          borderRadius: 16,
          builder: (focused, hovered) => Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
            ),
            child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? _Palette.accent : _Palette.textPrimary, size: 18),
          ),
        );
      },
    );
  }
}

/// The full-bleed featured banner at the top of the home screen.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.item, required this.onPlay, required this.onDetails, this.autofocus = false});

  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onDetails;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = screenHeight.clamp(0, 900) * 0.58;
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;

    return SizedBox(
      height: height.toDouble().clamp(360.0, 560.0),
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.posterUrl != null)
            Image.network(
              item.posterUrl.toString(),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              loadingBuilder: _imageSkeletonBuilder,
              errorBuilder: (context, _, _) => const ColoredBox(color: _Palette.surface),
            )
          else
            const ColoredBox(color: _Palette.surface),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x330F171E), Color(0xFF0F171E)],
                stops: [0.35, 0.7, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Palette.textPrimary, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(Icons.star, color: _Palette.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(context.formatDecimal(rating), style: const TextStyle(color: _Palette.textSecondary, fontSize: 13)),
                      const SizedBox(width: 12),
                    ],
                    if (year != null) Text('$year', style: const TextStyle(color: _Palette.textSecondary, fontSize: 13)),
                  ],
                ),
                if (item.overview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Palette.textSecondary, fontSize: 14, height: 1.3),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (item.isReleased)
                      _HeroButton(
                        label: HomeTranslations.play.trOf(context),
                        icon: Icons.play_arrow_rounded,
                        filled: true,
                        autofocus: autofocus,
                        onTap: onPlay,
                      ),
                    if (item.isReleased) const SizedBox(width: 12),
                    _HeroButton(
                      label: HomeTranslations.details.trOf(context),
                      icon: Icons.info_outline,
                      filled: false,
                      autofocus: autofocus && !item.isReleased,
                      onTap: onDetails,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.label, required this.icon, required this.filled, required this.onTap, this.autofocus = false});

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      autofocus: autofocus,
      borderRadius: 6,
      builder: (focused, hovered) {
        final background = filled ? _Palette.accent : (hovered ? _Palette.surface.withValues(alpha: 0.9) : _Palette.surface.withValues(alpha: 0.7));
        final foreground = filled ? const Color(0xFF06202B) : _Palette.textPrimary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A titled horizontal carousel of poster cards.
class _CarouselRow extends StatelessWidget {
  const _CarouselRow({required this.title, required this.itemCount, required this.cardBuilder, this.onSeeAll, this.seeAllLabel, this.cardHeight = 188});

  final String title;
  final int itemCount;
  final Widget Function(BuildContext context, int index) cardBuilder;
  final VoidCallback? onSeeAll;
  final String? seeAllLabel;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _Palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (onSeeAll != null && seeAllLabel != null)
                    _Pressable(
                      onTap: onSeeAll,
                      borderRadius: 4,
                      builder: (focused, hovered) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 1.5),
                        ),
                        child: Text(
                          seeAllLabel!,
                          style: TextStyle(color: hovered ? _Palette.textPrimary : _Palette.accent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: itemCount,
                separatorBuilder: (context, _) => const SizedBox(width: 12),
                itemBuilder: cardBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({required this.item, required this.video, required this.onDetails, required this.onPlay});

  final MediaItem item;
  final MediaVideo video;
  final VoidCallback onDetails;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.site == 'YouTube' ? Uri.https('i.ytimg.com', '/vi/${video.key}/hqdefault.jpg') : item.posterUrl;
    final playLabel = '${HomeTranslations.play.trOf(context)}: ${item.title}';
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnail != null)
                    Image.network(
                      thumbnail.toString(),
                      fit: BoxFit.cover,
                      loadingBuilder: _imageSkeletonBuilder,
                      errorBuilder: (context, _, _) => const _PosterPlaceholder(),
                    )
                  else
                    const _PosterPlaceholder(),
                  const ColoredBox(color: Color(0x33000000)),
                  Center(
                    child: Tooltip(
                      message: playLabel,
                      child: Semantics(
                        label: playLabel,
                        button: true,
                        child: _Pressable(
                          onTap: onPlay,
                          borderRadius: 28,
                          builder: (focused, hovered) => Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: hovered || focused ? _Palette.accent : const Color(0xCC000000),
                              shape: BoxShape.circle,
                              border: Border.all(color: _Palette.focus, width: focused ? 3 : 1),
                            ),
                            child: const Icon(Icons.play_arrow, color: _Palette.textPrimary, size: 34),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Pressable(
            onTap: onDetails,
            borderRadius: 4,
            builder: (focused, hovered) => Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: focused || hovered ? _Palette.accent : _Palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            video.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _Palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A single 2:3 poster tile used in every carousel row.
class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.item,
    required this.mediaType,
    required this.favoritesController,
    required this.onTap,
    this.badgeLabel,
    this.showResumeBadge = false,
    this.onResume,
  });

  final MediaItem item;
  final MediaType mediaType;
  final FavoritesController favoritesController;
  final VoidCallback onTap;
  final String? badgeLabel;
  final bool showResumeBadge;

  /// Tapped by the resume badge's play button; falls back to [onTap] when null.
  final VoidCallback? onResume;

  static const double _width = 125;
  static const double _height = 188;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 8,
      builder: (focused, hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _width,
          transform: hovered ? (Matrix4.identity()..scaleByDouble(1.04, 1.04, 1.04, 1.0)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.posterUrl != null)
                  Image.network(
                    item.posterUrl.toString(),
                    width: _width,
                    height: _height,
                    fit: BoxFit.cover,
                    loadingBuilder: _imageSkeletonBuilder,
                    errorBuilder: (context, _, _) => const _PosterPlaceholder(),
                  )
                else
                  const _PosterPlaceholder(),
                if (badgeLabel != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    left: 0,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _PosterBadge(label: badgeLabel!),
                    ),
                  ),
                if (showResumeBadge)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC000000)]),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: onResume == null
                            ? const Icon(Icons.play_circle_fill, color: _Palette.textPrimary, size: 26)
                            : _Pressable(
                                onTap: onResume,
                                borderRadius: 20,
                                builder: (focused, hovered) => Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
                                  ),
                                  child: const Icon(Icons.play_circle_fill, color: _Palette.textPrimary, size: 26),
                                ),
                              ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: _PosterLikeButton(item: item, mediaType: mediaType, controller: favoritesController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PosterBadge extends StatelessWidget {
  const _PosterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w800, height: 1),
          ),
        ),
      ),
    );
  }
}

String? _posterBadgeLabel(MediaItem item, MediaType mediaType, BuildContext context) {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  bool isRecent(DateTime? date) => date != null && !date.isAfter(now) && !date.isBefore(cutoff);

  if (mediaType == MediaType.movie) {
    return isRecent(item.releaseDate) ? HomeTranslations.newMovie.trOf(context) : null;
  }

  if (isRecent(item.releaseDate)) return HomeTranslations.newSeries.trOf(context);
  final hasOnlyOneReleasedSeason = item.releasedSeasonCount == 1 || (item.releasedSeasonCount == null && item.numberOfSeasons == 1);
  if (hasOnlyOneReleasedSeason && (isRecent(item.latestSeasonAirDate) || isRecent(item.latestEpisodeAirDate))) {
    return HomeTranslations.newSeries.trOf(context);
  }
  if (isRecent(item.latestSeasonAirDate)) return HomeTranslations.seasonPremiere.trOf(context);
  if (isRecent(item.latestEpisodeAirDate)) {
    return item.latestEpisodeNumber == 1 ? HomeTranslations.seasonPremiere.trOf(context) : HomeTranslations.newSeason.trOf(context);
  }
  return null;
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _Palette.surface,
      child: Center(child: Icon(Icons.movie_outlined, color: _Palette.textSecondary, size: 32)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _Palette.textSecondary, size: 44),
          const SizedBox(height: 12),
          Text(HomeTranslations.loadError.trOf(context), style: const TextStyle(color: _Palette.textSecondary, fontSize: 15)),
          const SizedBox(height: 16),
          _HeroButton(label: HomeTranslations.retry.trOf(context), icon: Icons.refresh, filled: true, onTap: onRetry),
        ],
      ),
    );
  }
}

/// A subtle left-to-right shimmer applied over its (opaque) skeleton [child],
/// used for loading placeholders instead of a spinner.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final slide = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(slide - 1, 0),
            end: Alignment(slide + 1, 0),
            colors: const [_Palette.surface, Color(0xFF2A3A49), _Palette.surface],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// An opaque rounded box used as a shimmer skeleton building block.
class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: _Palette.surface, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Loading placeholder shown in place of a not-yet-decoded network image.
Widget _imageSkeletonBuilder(BuildContext context, Widget child, ImageChunkEvent? progress) {
  if (progress == null) return child;
  return const _Shimmer(child: SizedBox.expand(child: _SkeletonBox(radius: 0)));
}

/// A skeleton of the browse home (hero + two carousel rows) shown while the
/// catalogue loads.
class _BrowseSkeleton extends StatelessWidget {
  const _BrowseSkeleton();

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height.clamp(0, 900) * 0.58).toDouble().clamp(360.0, 560.0);
    return SafeArea(
      bottom: false,
      child: _Shimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: _SkeletonBox(height: 44, radius: 22)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SkeletonBox(height: heroHeight, radius: 0),
            ),
            const _SkeletonRow(),
            const _SkeletonRow(),
          ],
        ),
      ),
    );
  }
}

/// A titled row of poster skeletons matching [_CarouselRow]'s metrics.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 10), child: _SkeletonBox(width: 160, height: 18, radius: 6)),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, _) => const _SkeletonBox(width: 125, height: 188),
          ),
        ),
      ],
    );
  }
}

/// A skeleton grid matching the search results grid, shown while a query runs.
class _SearchGridSkeleton extends StatelessWidget {
  const _SearchGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        itemCount: 12,
        itemBuilder: (context, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _SkeletonBox(radius: 8)),
            SizedBox(height: 6),
            _SkeletonBox(height: 10, radius: 3),
            SizedBox(height: 4),
            _SkeletonBox(width: 70, height: 10, radius: 3),
          ],
        ),
      ),
    );
  }
}

class RadioSection extends StatelessWidget {
  const RadioSection({super.key, required this.controller});

  final RadioController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  RadioTranslations.title.trOf(context),
                  style: const TextStyle(color: _Palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                _CountrySelector(countries: controller.countries, selectedCountry: controller.selectedCountry, onSelected: controller.selectCountry),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(RadioTranslations.attribution.trOf(context), style: const TextStyle(color: _Palette.textSecondary, fontSize: 12)),
          ),
          if (controller.isLoading)
            SizedBox(
              height: 88,
              child: Center(
                child: CircularProgressIndicator(color: _Palette.accent, semanticsLabel: RadioTranslations.loading.trOf(context)),
              ),
            )
          else if (controller.hasError)
            _LiveTvMessage(
              text: RadioTranslations.unavailable.trOf(context),
              actionLabel: HomeTranslations.retry.trOf(context),
              onAction: controller.load,
            )
          else if (controller.stations.isEmpty)
            _LiveTvMessage(text: RadioTranslations.empty.trOf(context))
          else
            SizedBox(
              height: 164,
              child: ListView.separated(
                key: ValueKey(controller.selectedCountry),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.stations.length,
                separatorBuilder: (context, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => RadioStationCard(station: controller.stations[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class RadioStationCard extends StatelessWidget {
  const RadioStationCard({super.key, required this.station});

  final RadioStation station;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => context.push(AppRoutes.radio(station.id), extra: station),
      borderRadius: 8,
      builder: (focused, hovered) => Container(
        width: 164,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _Palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused
                ? _Palette.focus
                : hovered
                ? _Palette.accent
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: RadioLogo(station: station)),
                  const Positioned(bottom: 0, left: 0, child: Icon(Icons.play_circle_fill, color: _Palette.textPrimary, size: 30)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              station.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              station.country,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Palette.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveTvSection extends StatelessWidget {
  const LiveTvSection({super.key, required this.controller});

  final LiveTvController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final channels = controller.channels;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 2),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    HomeTranslations.liveTv.trOf(context),
                    style: const TextStyle(color: _Palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  _CountrySelector(
                    countries: controller.countries,
                    selectedCountry: controller.selectedCountry,
                    onSelected: controller.selectCountry,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(HomeTranslations.liveTvAttribution.trOf(context), style: const TextStyle(color: _Palette.textSecondary, fontSize: 12)),
            ),
            if (controller.isLoading)
              SizedBox(
                height: 88,
                child: Center(
                  child: CircularProgressIndicator(color: _Palette.accent, semanticsLabel: HomeTranslations.liveTvLoading.trOf(context)),
                ),
              )
            else if (controller.hasError)
              _LiveTvMessage(
                text: HomeTranslations.liveTvUnavailable.trOf(context),
                actionLabel: HomeTranslations.retry.trOf(context),
                onAction: controller.load,
              )
            else if (channels.isEmpty)
              _LiveTvMessage(text: HomeTranslations.noLiveChannels.trOf(context))
            else
              SizedBox(
                height: 142,
                child: ListView.separated(
                  key: ValueKey(controller.selectedCountry),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: channels.length,
                  separatorBuilder: (context, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => LiveTvChannelCard(channel: channels[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({required this.countries, required this.selectedCountry, required this.onSelected});

  final List<LiveTvCountry> countries;
  final String? selectedCountry;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final sortedCountries = countries.toList()..sort((first, second) => first.localizedName(locale).compareTo(second.localizedName(locale)));
    return SizedBox(
      width: 240,
      child: Semantics(
        label: HomeTranslations.country.trOf(context),
        child: Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _Palette.accent, surface: _Palette.surface)),
          child: DropdownMenu<String>(
            key: ValueKey(locale.toLanguageTag()),
            width: 240,
            menuHeight: 300,
            initialSelection: selectedCountry ?? '',
            enableFilter: true,
            requestFocusOnTap: true,
            enabled: countries.isNotEmpty,
            textStyle: const TextStyle(color: _Palette.textPrimary, fontSize: 14),
            filterCallback: (entries, query) {
              final search = query.trim().toLowerCase();
              return entries.where((entry) =>
                entry.value.isEmpty || entry.label.toLowerCase().contains(search) || entry.value.toLowerCase().contains(search)).toList();
            },
            dropdownMenuEntries: [
              DropdownMenuEntry(value: '', label: HomeTranslations.allCountries.trOf(context)),
              for (final country in sortedCountries)
                if (isWindows)
                  // Windows has no flag emoji glyphs, so render flag images instead.
                  DropdownMenuEntry(
                    value: country.code,
                    label: country.localizedName(locale),
                    leadingIcon: SizedBox(
                      width: 24,
                      child: Image.network(
                        'https://flagcdn.com/w40/${country.code.toLowerCase()}.png',
                        errorBuilder: (_, _, _) => Text(country.code, style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  )
                else
                  DropdownMenuEntry(value: country.code, label: '${country.flag}  ${country.localizedName(locale)}'),
            ],
            onSelected: (value) {
              if (value != null) onSelected(value.isEmpty ? null : value);
            },
          ),
        ),
      ),
    );
  }
}

class _LiveTvMessage extends StatelessWidget {
  const _LiveTvMessage({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: _Palette.textSecondary, fontSize: 14)),
          ),
          if (actionLabel != null && onAction != null)
            _Pressable(
              onTap: onAction,
              borderRadius: 18,
              builder: (focused, hovered) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: hovered || focused ? _Palette.accent : _Palette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: _Palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LiveTvChannelCard extends StatelessWidget {
  const LiveTvChannelCard({super.key, required this.channel});

  final LiveTvChannel channel;

  void _play(BuildContext context) {
    context.push(AppRoutes.liveTvWatch(channel.id), extra: channel);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = channel.categories.isNotEmpty ? channel.categories.take(2).join(' · ') : channel.country;
    return _Pressable(
      onTap: () => context.push(AppRoutes.liveTvDetails(channel.id), extra: channel),
      borderRadius: 8,
      builder: (focused, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 164,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _Palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused
                ? _Palette.focus
                : hovered
                ? _Palette.accent
                : Colors.transparent,
            width: focused ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: LiveTvLogo(channel: channel)),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Semantics(
                      label: '${HomeTranslations.play.trOf(context)} ${channel.name}',
                      button: true,
                      child: Tooltip(
                        message: HomeTranslations.play.trOf(context),
                        child: _Pressable(
                          onTap: () => _play(context),
                          borderRadius: 20,
                          builder: (focused, hovered) => Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: hovered ? _Palette.accent : const Color(0xCC000000),
                              shape: BoxShape.circle,
                              border: Border.all(color: focused ? _Palette.focus : Colors.transparent, width: 2),
                            ),
                            child: const Icon(Icons.play_circle_fill, color: _Palette.textPrimary, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        HomeTranslations.liveLabel.trOf(context),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, height: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _Palette.textSecondary, fontSize: 11),
              ),
            if (channel.isGeoBlocked)
              Tooltip(
                message: HomeTranslations.geoRestrictedInfo.trOf(context),
                child: Row(
                  children: [
                    const Icon(Icons.public_off, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        HomeTranslations.geoRestricted.trOf(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.amber, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A cross-framework pressable that also responds to D-pad/remote select keys
/// and exposes focus/hover state to its [builder]. Avoids Material's [InkWell]
/// so it can be used inside the Fluent and macOS shells too.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.builder, required this.onTap, this.autofocus = false, this.borderRadius = 8});

  final Widget Function(bool focused, bool hovered) builder;
  final VoidCallback? onTap;
  final bool autofocus;
  final double borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _focused = false;
  bool _hovered = false;

  static final _activationKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (widget.onTap != null && _activationKeys.contains(event.logicalKey)) {
      widget.onTap!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: _onKey,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: widget.builder(_focused, _hovered)),
      ),
    );
  }
}
