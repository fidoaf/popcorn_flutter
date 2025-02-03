import 'package:popcorn_flutter/app/core/application_configuration.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/core/use_case/search_media_info.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';

class MediaSearchController {
  final SearchMediaInfo _searcher = const SearchMediaInfo(searcher: OMDBSearcher(secretKey: omdbKeySecret));

  Future<MediaSearchResult> search({required String terms, int page = 0, MediaType? type}) {
    return _searcher.searchMedia(query: terms, page: page, type: type);
  }
}
