import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_exception.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// [MediaSearchRepository] backed by The Movie Database (TMDB) REST API.
final class TmdbMediaSearchRepository implements MediaSearchRepository {
  TmdbMediaSearchRepository({required String accessToken, http.Client? client})
    // ignore: prefer_initializing_formals -- named parameters cannot be private.
    : _accessToken = accessToken,
      _client = client ?? http.Client();

  static const String _searchBaseUrl = 'https://api.themoviedb.org/3/search';
  static const String _posterBaseUrl = 'https://image.tmdb.org/t/p/w500';

  final String _accessToken;
  final http.Client _client;

  @override
  Future<List<MediaItem>> search(String query, MediaType mediaType) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const <MediaItem>[];
    }

    final endpoint = Uri.parse('$_searchBaseUrl/${_pathSegment(mediaType)}');
    final uri = endpoint.replace(queryParameters: {'query': trimmedQuery, 'include_adult': 'false'});

    final http.Response response;
    try {
      response = await _client.get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'});
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB search failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>?) ?? const <dynamic>[];
    return results.cast<Map<String, dynamic>>().map(_toMediaItem).toList(growable: false);
  }

  static String _pathSegment(MediaType mediaType) => switch (mediaType) {
    MediaType.movie => 'movie',
    MediaType.tv => 'tv',
  };

  MediaItem _toMediaItem(Map<String, dynamic> json) {
    final posterPath = json['poster_path'] as String?;
    // Movies expose `title`/`release_date`, TV series expose `name`/`first_air_date`.
    final title = (json['title'] as String?) ?? (json['name'] as String?) ?? '';
    final releaseDate = (json['release_date'] as String?) ?? (json['first_air_date'] as String?);
    return MediaItem(
      id: json['id'] as int,
      title: title,
      overview: (json['overview'] as String?) ?? '',
      posterUrl: posterPath == null ? null : Uri.parse('$_posterBaseUrl$posterPath'),
      releaseDate: _parseDate(releaseDate),
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
