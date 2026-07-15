import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Material (Android) UI for searching movies and TV series, driven by a [MediaSearchController].
class MaterialMediaSearchView extends StatefulWidget {
  const MaterialMediaSearchView({super.key, required this.controller, this.onMediaSelected});

  final MediaSearchController controller;
  final ValueChanged<MediaItem>? onMediaSelected;

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

    return ListTile(
      leading: _Poster(url: item.posterUrl),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(year == null ? item.overview : '$year · ${item.overview}', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: rating == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 18), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))]),
      onTap: onTap == null ? null : () => onTap!(item),
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
