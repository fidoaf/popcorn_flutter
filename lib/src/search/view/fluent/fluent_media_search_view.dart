import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/pointer_capability.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Fluent (Windows) UI for searching movies and TV series, driven by a [MediaSearchController].
class FluentMediaSearchView extends StatefulWidget {
  const FluentMediaSearchView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay});

  final MediaSearchController controller;

  /// Called when a result row is tapped (opens the details page).
  final ValueChanged<MediaItem>? onMediaSelected;

  /// Called when a result's play button is tapped (goes straight to the player).
  final ValueChanged<MediaItem>? onMediaPlay;

  @override
  State<FluentMediaSearchView> createState() => _FluentMediaSearchViewState();
}

class _FluentMediaSearchViewState extends State<FluentMediaSearchView> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.search(_queryController.text);

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(padding: 16, title: Text(SearchTranslations.pageTitle.trOf(context))),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextBox(
              controller: _queryController,
              placeholder: SearchTranslations.searchPlaceholder.trOf(context),
              onSubmitted: (_) => _submit(),
              prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 4), child: Icon(FluentIcons.search)),
              suffix: IconButton(icon: const Icon(FluentIcons.chevron_right), onPressed: _submit),
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
            child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _buildBody(context, widget.controller.state)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, MediaSearchState state) {
    return switch (state) {
      MediaSearchIdle() => Center(child: Text(SearchTranslations.idleHint.trOf(context))),
      MediaSearchLoading() => const Center(child: ProgressRing()),
      MediaSearchFailure(:final message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: InfoBar(title: Text(SearchTranslations.errorTitle.trOf(context)), content: Text(message), severity: InfoBarSeverity.error),
        ),
      ),
      MediaSearchSuccess(:final items) when items.isEmpty => Center(child: Text(SearchTranslations.emptyResults.trOf(context))),
      MediaSearchSuccess(:final items) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) => _MediaResultTile(item: items[index], onTap: widget.onMediaSelected, onPlay: widget.onMediaPlay),
      ),
    };
  }
}

class _MediaResultTile extends StatefulWidget {
  const _MediaResultTile({required this.item, this.onTap, this.onPlay});

  final MediaItem item;
  final ValueChanged<MediaItem>? onTap;
  final ValueChanged<MediaItem>? onPlay;

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
      if (rating != null) ...[const Icon(FluentIcons.favorite_star_fill), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))],
      if (showPlay && widget.onPlay != null) ...[
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
