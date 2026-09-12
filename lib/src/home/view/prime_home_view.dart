import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/home/view/home_feed_controller.dart';
import 'package:popcorn_flutter/src/home/view/home_translations.dart';
import 'package:popcorn_flutter/src/locale/view/locale_formatting.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Fixed dark palette so the browse experience looks identical across the
/// Material, Fluent and macOS shells (Prime Video is always dark).
abstract final class _Palette {
  static const background = Color(0xFF0F171E);
  static const backgroundTop = Color(0xFF16212B);
  static const surface = Color(0xFF1A242F);
  static const accent = Color(0xFF1FAAE2);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9BA9B4);
  static const focus = Color(0xFFFFFFFF);
}

/// A framework-agnostic, Amazon Prime Video-style home screen: a full-bleed
/// hero banner over horizontally scrolling poster carousels (continue watching,
/// my list, trending movies, trending TV series).
///
/// Content is wrapped in a transparent [Material] and uses a fixed dark palette
/// so the exact same layout renders inside every platform shell (Material,
/// Fluent, macOS) without depending on the surrounding theme.
class PrimeHomeView extends StatefulWidget {
  const PrimeHomeView({
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
  });

  final HomeFeedController feedController;
  final FavoritesController favoritesController;
  final WatchHistoryController historyController;

  /// Drives the inline search overlay (results, trending, media type).
  final MediaSearchController searchController;

  /// Opens the details page for a catalogue entry.
  final void Function(MediaItem item, MediaType type) onOpenDetails;

  /// Starts playback of the hero title.
  final void Function(MediaItem item, MediaType type) onPlay;

  /// Resumes playback of a continue-watching entry (with its season/episode).
  final void Function(WatchHistoryEntry entry) onResume;

  /// Optional "see all" targets for the corresponding rows.
  final VoidCallback? onSeeAllFavorites;
  final VoidCallback? onSeeAllHistory;

  /// Autofocuses the hero action and draws focus highlights for D-pad/remote
  /// navigation (Fire TV).
  final bool enableDpadFocus;

  @override
  State<PrimeHomeView> createState() => _PrimeHomeViewState();
}

class _PrimeHomeViewState extends State<PrimeHomeView> {
  bool _searchActive = false;

  void _openSearch() => setState(() => _searchActive = true);

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
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _searchActive
                    ? _SearchOverlay(
                        key: const ValueKey('search-overlay'),
                        controller: widget.searchController,
                        enableDpadFocus: widget.enableDpadFocus,
                        onClose: _closeSearch,
                        onOpenDetails: (item) => widget.onOpenDetails(item, widget.searchController.mediaType),
                        onPlay: (item) => widget.onPlay(item, widget.searchController.mediaType),
                      )
                    : const SizedBox.shrink(key: ValueKey('search-none')),
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
          SliverToBoxAdapter(child: _SearchBar(onTap: _openSearch)),
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
                return _PosterCard(item: entry.item, showResumeBadge: true, onTap: () => widget.onResume(entry));
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
                return _PosterCard(item: favorite.item, onTap: () => widget.onOpenDetails(favorite.item, favorite.type));
              },
            ),
          if (feedController.trendingMovies.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.trendingMovies.trOf(context),
              itemCount: feedController.trendingMovies.length,
              cardBuilder: (context, index) {
                final item = feedController.trendingMovies[index];
                return _PosterCard(item: item, onTap: () => widget.onOpenDetails(item, MediaType.movie));
              },
            ),
          if (feedController.trendingTv.isNotEmpty)
            _CarouselRow(
              title: HomeTranslations.trendingTv.trOf(context),
              itemCount: feedController.trendingTv.length,
              cardBuilder: (context, index) {
                final item = feedController.trendingTv[index];
                return _PosterCard(item: item, onTap: () => widget.onOpenDetails(item, MediaType.tv));
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// A rounded, tappable bar that opens the search screen.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: _Pressable(
        onTap: onTap,
        borderRadius: 22,
        builder: (focused, hovered) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _Palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: focused ? _Palette.focus : _Palette.textSecondary.withValues(alpha: 0.25), width: focused ? 2 : 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: _Palette.textSecondary, size: 20),
              const SizedBox(width: 10),
              Text(HomeTranslations.search.trOf(context), style: const TextStyle(color: _Palette.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-cover search panel that slides over the browse home (Prime-style):
/// an autofocused input, a movie/TV toggle and a live results grid driven by
/// the shared [MediaSearchController].
class _SearchOverlay extends StatefulWidget {
  const _SearchOverlay({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onOpenDetails,
    required this.onPlay,
    this.enableDpadFocus = false,
  });

  final MediaSearchController controller;
  final VoidCallback onClose;
  final ValueChanged<MediaItem> onOpenDetails;
  final ValueChanged<MediaItem> onPlay;
  final bool enableDpadFocus;

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.controller.query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Debounce keystrokes so we don't fire a request on every character.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => widget.controller.search(value));
  }

  void _submit() {
    _debounce?.cancel();
    widget.controller.search(_queryController.text);
  }

  void _clear() {
    _debounce?.cancel();
    _queryController.clear();
    widget.controller.clear();
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: ColoredBox(
        color: _Palette.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
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
                    const SizedBox(width: 4),
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
                                autofocus: !widget.enableDpadFocus,
                                onChanged: _onChanged,
                                onSubmitted: (_) => _submit(),
                                textInputAction: TextInputAction.search,
                                cursorColor: _Palette.accent,
                                style: const TextStyle(color: _Palette.textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: SearchTranslations.searchPlaceholder.trOf(context),
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
              _MediaTypeToggle(controller: widget.controller),
              Expanded(
                child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _buildResults(context)),
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
              return _SearchResultCard(item: item, autofocus: widget.enableDpadFocus && index == 0, onTap: () => widget.onOpenDetails(item));
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }
}

/// The movie/TV switch shown above the search results.
class _MediaTypeToggle extends StatelessWidget {
  const _MediaTypeToggle({required this.controller});

  final MediaSearchController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            _chip(context, MediaType.movie, SearchTranslations.mediaMovies.trOf(context)),
            const SizedBox(width: 10),
            _chip(context, MediaType.tv, SearchTranslations.mediaTvSeries.trOf(context)),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, MediaType type, String label) {
    final selected = controller.mediaType == type;
    return _Pressable(
      onTap: () => controller.setMediaType(type),
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
  const _SearchResultCard({required this.item, required this.onTap, this.autofocus = false});

  final MediaItem item;
  final VoidCallback onTap;
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
  const _CarouselRow({required this.title, required this.itemCount, required this.cardBuilder, this.onSeeAll, this.seeAllLabel});

  final String title;
  final int itemCount;
  final Widget Function(BuildContext context, int index) cardBuilder;
  final VoidCallback? onSeeAll;
  final String? seeAllLabel;

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
              height: 188,
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

/// A single 2:3 poster tile used in every carousel row.
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.item, required this.onTap, this.showResumeBadge = false});

  final MediaItem item;
  final VoidCallback onTap;
  final bool showResumeBadge;

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
                      child: const Row(children: [Icon(Icons.play_circle_fill, color: _Palette.textPrimary, size: 22)]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
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
