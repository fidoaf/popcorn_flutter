import 'package:popcorn_flutter/search/core/model/media_list.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';

class MediaSearchResult {
  final MediaList list;
  final List<String>? errors;
  final int totalCount;
  final bool hasNextPage;
  const MediaSearchResult({this.list = const MediaList.empty(), this.totalCount = 0, this.hasNextPage = false, this.errors});

  bool get success => list.items.isNotEmpty;
}

abstract class IMediaSearcher {
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request);
}
