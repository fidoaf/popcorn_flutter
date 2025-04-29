class MediaPlayerSettings {
  final String url;
  final bool hasPrevious;
  final bool hasNext;
  const MediaPlayerSettings({required this.url, this.hasPrevious = false, this.hasNext = false});
}
