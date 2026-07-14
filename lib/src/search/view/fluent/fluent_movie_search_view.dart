import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/movie.dart';
import 'package:popcorn_flutter/src/search/view/movie_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/movie_search_state.dart';
import 'package:popcorn_flutter/src/search/view/search_translations.dart';

/// Fluent (Windows) UI for searching movies, driven by a [MovieSearchController].
class FluentMovieSearchView extends StatefulWidget {
  const FluentMovieSearchView({super.key, required this.controller, this.onMovieSelected});

  final MovieSearchController controller;
  final ValueChanged<Movie>? onMovieSelected;

  @override
  State<FluentMovieSearchView> createState() => _FluentMovieSearchViewState();
}

class _FluentMovieSearchViewState extends State<FluentMovieSearchView> {
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
          child: Row(
            children: [
              Expanded(
                child: TextBox(controller: _queryController, placeholder: SearchTranslations.searchPlaceholder.trOf(context), onSubmitted: (_) => _submit()),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _submit, child: Text(SearchTranslations.searchButton.trOf(context))),
            ],
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
      MovieSearchLoading() => const Center(child: ProgressRing()),
      MovieSearchFailure(:final message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: InfoBar(title: Text(SearchTranslations.errorTitle.trOf(context)), content: Text(message), severity: InfoBarSeverity.error),
        ),
      ),
      MovieSearchSuccess(:final movies) when movies.isEmpty => Center(child: Text(SearchTranslations.emptyResults.trOf(context))),
      MovieSearchSuccess(:final movies) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _MovieResultCard(movie: movies[index], onTap: widget.onMovieSelected),
      ),
    };
  }
}

class _MovieResultCard extends StatelessWidget {
  const _MovieResultCard({required this.movie, this.onTap});

  final Movie movie;
  final ValueChanged<Movie>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final year = movie.releaseDate?.year;
    final rating = movie.voteAverage;

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(movie),
      child: Card(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Poster(url: movie.posterUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: theme.typography.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (year != null) Text('$year', style: theme.typography.caption),
                  const SizedBox(height: 4),
                  Text(movie.overview, style: theme.typography.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (rating != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const Icon(FluentIcons.favorite_star_fill), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 60;
  static const double _height = 90;

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
