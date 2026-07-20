import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Material (Android) UI for searching movies and TV series, driven by a [MediaSearchController].
class MaterialMediaSearchView extends StatefulWidget {
  const MaterialMediaSearchView({super.key, required this.controller, this.onMediaSelected, this.enableDpadFocus = false});

  final MediaSearchController controller;
  final ValueChanged<MediaItem>? onMediaSelected;

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
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.search(_queryController.text);

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
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _submit),
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
          dpadFocus: widget.enableDpadFocus,
          autofocus: widget.enableDpadFocus && index == 0,
        ),
      ),
    };
  }
}

class _MediaResultTile extends StatefulWidget {
  const _MediaResultTile({required this.item, this.onTap, this.autofocus = false, this.dpadFocus = false});

  final MediaItem item;
  final ValueChanged<MediaItem>? onTap;
  final bool autofocus;
  final bool dpadFocus;

  @override
  State<_MediaResultTile> createState() => _MediaResultTileState();
}

class _MediaResultTileState extends State<_MediaResultTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;

    final tile = ListTile(
      autofocus: widget.autofocus,
      // Roomier rows on TV so posters/text aren't tiny from across the room.
      contentPadding: widget.dpadFocus ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12) : null,
      onFocusChange: widget.dpadFocus ? (hasFocus) => setState(() => _focused = hasFocus) : null,
      leading: _Poster(url: item.posterUrl, large: widget.dpadFocus),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(year == null ? item.overview : '$year · ${item.overview}', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: rating == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: widget.dpadFocus ? 28 : 18),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1)),
              ],
            ),
      onTap: widget.onTap == null ? null : () => widget.onTap!(item),
    );

    // Plain touch UI (Android phones): no persistent focus decoration.
    if (!widget.dpadFocus) return tile;

    final colorScheme = Theme.of(context).colorScheme;

    // Draw a prominent border/background when focused so the selection is
    // clearly visible from across the room when navigating with a D-pad.
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
