import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/movie.dart';
import 'package:popcorn_flutter/src/search/view/movie_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/movie_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Material (Android) UI for searching movies, driven by a [MovieSearchController].
class MaterialMovieSearchView extends StatefulWidget {
  const MaterialMovieSearchView({super.key, required this.controller, this.onMovieSelected});

  final MovieSearchController controller;
  final ValueChanged<Movie>? onMovieSelected;

  @override
  State<MaterialMovieSearchView> createState() => _MaterialMovieSearchViewState();
}

class _MaterialMovieSearchViewState extends State<MaterialMovieSearchView> {
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
          padding: const EdgeInsets.all(16),
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
        Expanded(
          child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _buildBody(context, widget.controller.state)),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, MovieSearchState state) {
    return switch (state) {
      MovieSearchIdle() => Center(child: Text(SearchTranslations.idleHint.trOf(context))),
      MovieSearchLoading() => const Center(child: CircularProgressIndicator()),
      MovieSearchFailure(:final message) => Center(
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
      MovieSearchSuccess(:final movies) when movies.isEmpty => Center(child: Text(SearchTranslations.emptyResults.trOf(context))),
      MovieSearchSuccess(:final movies) => ListView.builder(
        itemCount: movies.length,
        itemBuilder: (context, index) => _MovieResultTile(movie: movies[index], onTap: widget.onMovieSelected),
      ),
    };
  }
}

class _MovieResultTile extends StatelessWidget {
  const _MovieResultTile({required this.movie, this.onTap});

  final Movie movie;
  final ValueChanged<Movie>? onTap;

  @override
  Widget build(BuildContext context) {
    final year = movie.releaseDate?.year;
    final rating = movie.voteAverage;

    return ListTile(
      leading: _Poster(url: movie.posterUrl),
      title: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(year == null ? movie.overview : '$year · ${movie.overview}', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: rating == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 18), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))]),
      onTap: onTap == null ? null : () => onTap!(movie),
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
