import 'dart:convert';

import 'package:http/http.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_list.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_info.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_type.dart';

class OMDBSearcher implements IMediaSearcher {
  static const String _omdbHost = 'www.omdbapi.com';
  static const String _searchParam = 's';
  static const String _keyParam = 'apiKey';
  static const String _pageParam = 'page';
  static const String _typeParam = 'type';

  final String secretKey;
  const OMDBSearcher({required this.secretKey});

  @override
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request) async {
    final requestPage = request.page;
    final mediaType = request.type;
    final url = Uri.http(_omdbHost, '/', {
      _searchParam: request.terms,
      _keyParam: secretKey,
      if (mediaType != null) _typeParam: OMDBMediaTypeVO.fromType(mediaType),
      if (requestPage != null) _pageParam: '${requestPage + 1}',
    });
    final httpResponse = await get(url);
    if (httpResponse.statusCode == 200) {
      final rawData = httpResponse.body;
      final resultObj = jsonDecode(rawData);
      final hasResults = resultObj['Response'];
      if (hasResults == true || (hasResults is String && bool.tryParse(hasResults.toLowerCase()) == true)) {
        final items = resultObj['Search'] as List?;
        final numResults = int.tryParse(resultObj['totalResults']) ?? 0;
        final mediaList = items?.map((i) => OMDBItemVO.fromData(i)).whereType<MediaInfo>().toList() ?? [];
        return MediaSearchResult(list: MediaList(items: mediaList), totalCount: numResults, hasNextPage: true);
      } else {
        final error = resultObj['Error'];
        return MediaSearchResult(errors: error == null ? null : [error]);
      }
    } else {
      return const MediaSearchResult(errors: ['Unexpected error found on media search']);
    }
  }
}
