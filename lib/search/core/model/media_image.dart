enum MediaImageType {
  poster;
}

class MediaImage {
  final String url;
  final MediaImageType type;
  const MediaImage({required this.url, required this.type});
}
