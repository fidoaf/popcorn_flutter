/// Raised when a media search cannot be completed by the data source.
final class MediaSearchException implements Exception {
  const MediaSearchException(this.message);

  final String message;

  @override
  String toString() => 'MediaSearchException: $message';
}
