import 'package:popcorn_flutter/details/core/model/media_full_details.dart';
import 'package:popcorn_flutter/search/core/model/media_image.dart';
import 'package:popcorn_flutter/search/core/model/media_info_request.dart';
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

class MediaInfoResult {
  final MediaFullDetails? details;
  final List<String>? errors;
  const MediaInfoResult({this.details, this.errors});

  bool get success => details != null;
}

abstract class IMediaSearcher {
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request);
  Future<MediaInfoResult> getMediaDetails(MediaInfoRequest request);
}
