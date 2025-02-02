import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';

class MediaSearchResult {
  final List<MediaInfo> items;
  final List<String>? errors;
  const MediaSearchResult({this.items = const [], this.errors});
}

abstract class IMediaSearcher {
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request);
}
