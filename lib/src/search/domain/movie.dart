/// Immutable representation of a movie returned by a search query.
final class Movie {
  const Movie({required this.id, required this.title, required this.overview, this.posterUrl, this.releaseDate, this.voteAverage});

  final int id;
  final String title;
  final String overview;
  final Uri? posterUrl;
  final DateTime? releaseDate;
  final double? voteAverage;
}
