import 'dart:convert';

import 'package:http/http.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_info.dart';

class OMDBSearcher implements IMediaSearcher {
  static const String omdbHost = 'www.omdbapi.com';
  static const String searchParam = 's';
  static const String keyParam = 'apiKey';

  final String secretKey;
  const OMDBSearcher({required this.secretKey});

  @override
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request) async {
    final url = Uri.http(omdbHost, '/', {
      searchParam: request.terms,
      keyParam: secretKey,
    });
    final httpResponse = await get(url);
    if (httpResponse.statusCode == 200) {
      final rawData = httpResponse.body;
      final resultObj = jsonDecode(rawData);
      final hasResults = resultObj['Response'];
      if (hasResults == true || (hasResults is String && bool.tryParse(hasResults.toLowerCase()) == true)) {
        final items = resultObj['Search'] as List?;
        return MediaSearchResult(items: items?.map((i) => OMDBItemVO.fromData(i)).whereType<MediaInfo>().toList() ?? [], errors: null);
      } else {
        final error = resultObj['Error'];
        return MediaSearchResult(items: [], errors: error == null ? null : [error]);
      }
    } else {
      return const MediaSearchResult(items: [], errors: ['Unexpected error found on media search']);
    }
  }
}
