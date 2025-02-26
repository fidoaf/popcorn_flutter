import 'package:collection/collection.dart';

enum MediaImageType {
  poster;

  static MediaImageType? fromString(String text) => MediaImageType.values.firstWhereOrNull((mt) => mt.name == text);
}

class MediaImage {
  final String url;
  final MediaImageType type;
  const MediaImage({required this.url, required this.type});

  static MediaImage fromJson(Map<String, dynamic> data) {
    return MediaImage(url: data['url'], type: MediaImageType.fromString(data['type']) ?? MediaImageType.poster);
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type.name,
    };
  }
}
