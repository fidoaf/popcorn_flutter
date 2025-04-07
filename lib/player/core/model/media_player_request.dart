import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';

class MediaPlayerRequest {
  final String id;
  final MediaType type;
  final String? language;
  MediaPlayerRequest._({required this.id, required this.type, this.language});

  static MediaPlayerRequest create(MediaInfo info) {
    final id = info.id;
    if (id.isEmpty) throw Exception('Id is required');
    final type = info.type;
    if (type == null) throw Exception('Id is required');
    return MediaPlayerRequest._(id: id, type: type);
  }
}
