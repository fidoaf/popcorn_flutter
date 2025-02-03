import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class SearchMediaInfo implements UseCase {
  final IMediaSearcher _searcher;
  const SearchMediaInfo({required IMediaSearcher searcher}) : _searcher = searcher;

  Future<MediaSearchResult> searchMedia({required String? query, MediaType? type, int? page}) async {
    try {
      final request = MediaSearchRequest.create(terms: query, type: type, page: page);
      return _searcher.searchMedia(request);
    } catch (ex) {
      return MediaSearchResult(errors: [ex.toString()]);
    }
  }
}
