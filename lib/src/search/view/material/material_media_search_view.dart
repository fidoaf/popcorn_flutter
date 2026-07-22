import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/pointer_capability.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Material (Android) UI for searching movies and TV series, driven by a [MediaSearchController].
class MaterialMediaSearchView extends StatefulWidget {
  const MaterialMediaSearchView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay, this.enableDpadFocus = false});

  final MediaSearchController controller;

  /// Called when a result row is tapped (opens the details page).
  final ValueChanged<MediaItem>? onMediaSelected;

  /// Called when a result's play button is tapped (goes straight to the player).
  final ValueChanged<MediaItem>? onMediaPlay;

  /// When `true`, results autofocus the first tile and draw a prominent focus
  /// highlight for D-pad/remote navigation (Fire TV). Defaults to `false` so
  /// the touch UI stays clean with no persistent focus decoration.
  final bool enableDpadFocus;

  @override
  State<MaterialMediaSearchView> createState() => _MaterialMediaSearchViewState();
}

class _MaterialMediaSearchViewState extends State<MaterialMediaSearchView> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  void _submit() => widget.controller.search(_queryController.text);

  void _clear() {
    _queryController.clear();
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: SearchTranslations.searchPlaceholder.trOf(context),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _queryController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _clear) : null,
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
          child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _buildBody(context, widget.controller.state)),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, MediaSearchState state) {
    return switch (state) {
      MediaSearchIdle(:final trendingItems) when trendingItems.isNotEmpty => _buildTrendingList(context, trendingItems),
      MediaSearchIdle() => Center(child: Text(SearchTranslations.idleHint.trOf(context))),
      MediaSearchLoading() => const Center(child: CircularProgressIndicator()),
      MediaSearchFailure(:final message) => Center(
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
      ),
      MediaSearchSuccess(:final items) when items.isEmpty => Center(child: Text(SearchTranslations.emptyResults.trOf(context))),
      MediaSearchSuccess(:final items) => ListView.builder(
        itemCount: items.length,
        // In D-pad mode, autofocus the first result so a remote has an initial focus target.
        itemBuilder: (context, index) => _MediaResultTile(
          item: items[index],
          onTap: widget.onMediaSelected,
          onPlay: widget.onMediaPlay,
          dpadFocus: widget.enableDpadFocus,
          autofocus: widget.enableDpadFocus && index == 0,
        ),
      ),
    };
  }

  Widget _buildTrendingList(BuildContext context, List<MediaItem> items) {
    return ListView.builder(
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(SearchTranslations.trendingTitle.trOf(context), style: Theme.of(context).textTheme.titleMedium),
          );
        }
        return _MediaResultTile(
          item: items[index - 1],
          onTap: widget.onMediaSelected,
          onPlay: widget.onMediaPlay,
          dpadFocus: widget.enableDpadFocus,
          autofocus: widget.enableDpadFocus && index == 1,
        );
      },
    );
  }
}

class _MediaResultTile extends StatefulWidget {
  const _MediaResultTile({required this.item, this.onTap, this.onPlay, this.autofocus = false, this.dpadFocus = false});

  final MediaItem item;
  final ValueChanged<MediaItem>? onTap;
  final ValueChanged<MediaItem>? onPlay;
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
      subtitle: Text(year == null ? item.overview : '$year · ${item.overview}', maxLines: 2, overflow: TextOverflow.ellipsis),
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
      if (showPlay && widget.onPlay != null) ...[
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
