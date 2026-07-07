import 'dart:convert';

import 'package:http/http.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_info_request.dart';
import 'package:popcorn_flutter/search/core/model/media_list.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_details.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_info.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_type.dart';

class OMDBSearcher implements IMediaSearcher {
  static const String _omdbHost = 'www.omdbapi.com';
  static const String _searchParam = 's';
  static const String _idParam = 'i';
  static const String _keyParam = 'apiKey';
  static const String _pageParam = 'page';
  static const String _typeParam = 'type';

  final String secretKey;
  const OMDBSearcher({required this.secretKey});

  Map<String, dynamic>? _getSearchData(Response httpResponse) {
    final rawData = httpResponse.body;
    try {
      final resultObj = jsonDecode(rawData);
      return resultObj;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request) async {
    if (secretKey.isEmpty) {
      return const MediaSearchResult(errors: ['OMDb API key is not configured']);
    }

    final requestPage = request.page;
    final mediaType = request.type;
    final url = Uri.https(_omdbHost, '/', {
      _searchParam: request.terms,
      _keyParam: secretKey,
      if (mediaType != null) _typeParam: OMDBMediaTypeVO.fromType(mediaType),
      if (requestPage != null) _pageParam: '${requestPage + 1}',
    });

    final httpResponse = await get(url);
    final resultObj = _getSearchData(httpResponse);
    if (resultObj == null) {
      return const MediaSearchResult(
        errors: ['Unexpected error found on media search'],
      );
    } else {
      final response = resultObj['Response'];
      final hasResult =
          response == true ||
          (response is String && bool.tryParse(response.toLowerCase()) == true);
      if (hasResult) {
        final items = resultObj['Search'] as List?;
        final numResults = int.tryParse(resultObj['totalResults']) ?? 0;
        final mediaList =
            items
                ?.map((i) => OMDBItemVO.fromData(i))
                .whereType<MediaInfo>()
                .toList() ??
            [];
        return MediaSearchResult(
          list: MediaList(items: mediaList),
          totalCount: numResults,
          hasNextPage: true,
        );
      } else {
        final error = resultObj['Error'];
        return MediaSearchResult(
          errors: [error ?? 'Unexpected error found on media search'],
        );
      }
    }
  }

  @override
  Future<MediaInfoResult> getMediaDetails(MediaInfoRequest request) async {
    if (secretKey.isEmpty) {
      return const MediaInfoResult(errors: ['OMDb API key is not configured']);
    }

    final requestId = request.id;
    final url = Uri.https(_omdbHost, '/', {
      _idParam: requestId,
      _keyParam: secretKey,
    });
    final httpResponse = await get(url);
    if (httpResponse.statusCode == 200) {
      final rawData = httpResponse.body;
      final resultObj = jsonDecode(rawData);
      final hasResults = resultObj['Response'];
      if (hasResults == true ||
          (hasResults is String &&
              bool.tryParse(hasResults.toLowerCase()) == true)) {
        return MediaInfoResult(details: OMDBDetailsVO.fromData(resultObj));
      } else {
        final error = resultObj['Error'];
        return MediaInfoResult(errors: error == null ? null : [error]);
      }
    } else {
      return const MediaInfoResult(
        errors: ['Unexpected error found on media search'],
      );
    }
  }
}
