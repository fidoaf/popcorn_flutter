import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/core/use_case/search_media_info.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';

mixin SearchMixin {
  final _searcher = SearchMediaInfo(searcher: OMDBSearcher(secretKey: ServiceLocator.configuration.omdbKeySecret));

  Future<MediaSearchResult> search({required String terms, int page = 0, MediaType? type}) {
    return _searcher.searchMedia(query: terms, page: page, type: type);
  }
}