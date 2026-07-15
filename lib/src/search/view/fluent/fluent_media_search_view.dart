import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Fluent (Windows) UI for searching movies and TV series, driven by a [MediaSearchController].
class FluentMediaSearchView extends StatefulWidget {
  const FluentMediaSearchView({super.key, required this.controller, this.onMediaSelected});

  final MediaSearchController controller;
  final ValueChanged<MediaItem>? onMediaSelected;

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
        itemBuilder: (context, index) => _MediaResultTile(item: items[index], onTap: widget.onMediaSelected),
      ),
    };
  }
}

class _MediaResultTile extends StatelessWidget {
  const _MediaResultTile({required this.item, this.onTap});

  final MediaItem item;
  final ValueChanged<MediaItem>? onTap;

  @override
  Widget build(BuildContext context) {
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;
    final subtitle = year == null ? item.overview : '$year \u00b7 ${item.overview}';

    return ListTile.selectable(
      leading: _Poster(url: item.posterUrl),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: rating == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Icon(FluentIcons.favorite_star_fill), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))],
            ),
      selected: false,
      onSelectionChange: onTap == null ? null : (_) => onTap!(item),
    );
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
