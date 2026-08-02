import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_episode.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_exception.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// [MediaSearchRepository] backed by The Movie Database (TMDB) REST API.
final class TmdbMediaSearchRepository implements MediaSearchRepository {
  TmdbMediaSearchRepository({required String accessToken, http.Client? client})
    // ignore: prefer_initializing_formals -- named parameters cannot be private.
    : _accessToken = accessToken,
      _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _searchBaseUrl = '$_baseUrl/search';
  static const String _posterBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String _stillBaseUrl = 'https://image.tmdb.org/t/p/w300';

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
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB search request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
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

  @override
  Future<MediaDetails> details(int id, MediaType mediaType) async {
    final endpoint = Uri.parse('$_baseUrl/${_pathSegment(mediaType)}/$id');
    final uri = endpoint.replace(queryParameters: {'append_to_response': 'credits'});

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB details request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB details failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _toMediaDetails(decoded, mediaType);
  }

  @override
  Future<List<MediaItem>> trending(MediaType mediaType) async {
    final uri = Uri.parse('$_baseUrl/trending/${_pathSegment(mediaType)}/week');

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB trending request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB trending failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>?) ?? const <dynamic>[];
    return results.cast<Map<String, dynamic>>().map(_toMediaItem).toList(growable: false);
  }

  @override
  Future<List<MediaVideo>> videos(int id, MediaType mediaType) async {
    final uri = Uri.parse('$_baseUrl/${_pathSegment(mediaType)}/$id/videos');

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB videos request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB videos failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>?) ?? const <dynamic>[];
    return results.cast<Map<String, dynamic>>().map(_toMediaVideo).toList(growable: false);
  }

  @override
  Future<List<MediaEpisode>> episodes(int seriesId, int seasonNumber) async {
    final uri = Uri.parse('$_baseUrl/tv/$seriesId/season/$seasonNumber');

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB episodes request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB episodes failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['episodes'] as List<dynamic>?) ?? const <dynamic>[];
    return results.cast<Map<String, dynamic>>().map(_toMediaEpisode).toList(growable: false);
  }

  static MediaEpisode _toMediaEpisode(Map<String, dynamic> json) {
    final stillPath = json['still_path'] as String?;
    final runtime = (json['runtime'] as num?)?.toInt();
    return MediaEpisode(
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      stillUrl: stillPath == null ? null : Uri.parse('$_stillBaseUrl$stillPath'),
      airDate: _parseDate(json['air_date'] as String?),
      runtime: runtime == null || runtime <= 0 ? null : Duration(minutes: runtime),
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }

  static MediaDetails _toMediaDetails(Map<String, dynamic> json, MediaType mediaType) {
    final director = _director(json, mediaType);
    final cast = _cast(json);
    switch (mediaType) {
      case MediaType.movie:
        final minutes = (json['runtime'] as num?)?.toInt();
        return MediaDetails(
          runtime: minutes == null || minutes <= 0 ? null : Duration(minutes: minutes),
          director: director,
          cast: cast,
        );
      case MediaType.tv:
        final seasonsJson = (json['seasons'] as List<dynamic>?) ?? const <dynamic>[];
        final seasons = seasonsJson.cast<Map<String, dynamic>>().map(_toMediaSeason).toList(growable: false);
        return MediaDetails(
          numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
          numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
          seasons: seasons,
          director: director,
          cast: cast,
        );
    }
  }

  /// Maximum number of leading cast members to surface on the details page.
  static const int _maxCastMembers = 5;

  /// Resolves the director of a movie (crew member with job `Director`) or the
  /// creator(s) of a TV series (`created_by`). Returns `null` when unknown.
  static String? _director(Map<String, dynamic> json, MediaType mediaType) {
    final crew = (json['credits'] as Map<String, dynamic>?)?['crew'] as List<dynamic>?;
    final directors = <String>[];
    for (final member in (crew ?? const <dynamic>[]).cast<Map<String, dynamic>>()) {
      if (member['job'] == 'Director') {
        final name = (member['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty && !directors.contains(name)) directors.add(name);
      }
    }
    if (directors.isEmpty && mediaType == MediaType.tv) {
      final creators = (json['created_by'] as List<dynamic>?) ?? const <dynamic>[];
      for (final creator in creators.cast<Map<String, dynamic>>()) {
        final name = (creator['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty && !directors.contains(name)) directors.add(name);
      }
    }
    return directors.isEmpty ? null : directors.join(', ');
  }

  /// Resolves the leading [_maxCastMembers] cast members, ordered by billing.
  static List<String> _cast(Map<String, dynamic> json) {
    final cast = (json['credits'] as Map<String, dynamic>?)?['cast'] as List<dynamic>?;
    final names = <String>[];
    for (final member in (cast ?? const <dynamic>[]).cast<Map<String, dynamic>>()) {
      final name = (member['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) names.add(name);
      if (names.length >= _maxCastMembers) break;
    }
    return List<String>.unmodifiable(names);
  }

  static MediaSeason _toMediaSeason(Map<String, dynamic> json) {
    final posterPath = json['poster_path'] as String?;
    final episodeCount = (json['episode_count'] as num?)?.toInt();
    return MediaSeason(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      episodeCount: episodeCount == null || episodeCount <= 0 ? null : episodeCount,
      airDate: _parseDate(json['air_date'] as String?),
      overview: (json['overview'] as String?) ?? '',
      posterUrl: posterPath == null ? null : Uri.parse('$_posterBaseUrl$posterPath'),
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
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

  static MediaVideo _toMediaVideo(Map<String, dynamic> json) {
    return MediaVideo(
      id: json['id'] as String,
      key: json['key'] as String,
      name: (json['name'] as String?) ?? '',
      site: (json['site'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
    );
  }
}
