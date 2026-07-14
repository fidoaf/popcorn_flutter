/// Raised when a movie search cannot be completed by the data source.
final class MovieSearchException implements Exception {
  const MovieSearchException(this.message);

  final String message;

  @override
  String toString() => 'MovieSearchException: $message';
}
