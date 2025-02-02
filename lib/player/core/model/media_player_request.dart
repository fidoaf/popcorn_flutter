import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';

class MediaPlayerRequest {
  final String id;
  final MediaType type;
  MediaPlayerRequest._({required this.id, required this.type});

  static MediaPlayerRequest create(MediaInfo info) {
    final id = info.id;
    if (id.isEmpty) throw Exception('Id is required');
    final type = info.type;
    if (type == null) throw Exception('Id is required');
    return MediaPlayerRequest._(id: id, type: type);
  }
}
