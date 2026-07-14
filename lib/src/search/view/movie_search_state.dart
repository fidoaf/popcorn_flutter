import 'package:popcorn_flutter/src/search/domain/movie.dart';

/// Presentation state of a movie search, consumed by the views.
sealed class MovieSearchState {
  const MovieSearchState();
}

/// No search has been performed yet.
final class MovieSearchIdle extends MovieSearchState {
  const MovieSearchIdle();
}

/// A search request is in flight.
final class MovieSearchLoading extends MovieSearchState {
  const MovieSearchLoading();
}

/// A search completed successfully with [movies] (possibly empty).
final class MovieSearchSuccess extends MovieSearchState {
  const MovieSearchSuccess(this.movies);

  final List<Movie> movies;
}

/// A search failed with a human-readable [message].
final class MovieSearchFailure extends MovieSearchState {
  const MovieSearchFailure(this.message);

  final String message;
}
