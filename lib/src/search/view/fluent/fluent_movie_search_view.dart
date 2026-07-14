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
          Expanded(
            child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _buildBody(context, widget.controller.state)),
          ),
        ],
      ),
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
      MovieSearchSuccess(:final movies) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    final subtitle = year == null ? movie.overview : '$year \u00b7 ${movie.overview}';

    return ListTile.selectable(
      leading: _Poster(url: movie.posterUrl),
      title: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: rating == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Icon(FluentIcons.favorite_star_fill), const SizedBox(width: 4), Text(rating.toStringAsFixed(1))],
            ),
      selected: false,
      onSelectionChange: onTap == null ? null : (_) => onTap!(movie),
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
