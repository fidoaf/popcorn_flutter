import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/search/domain/cast_member.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_episode.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_person.dart';
import 'package:popcorn_flutter/src/search/domain/media_production_status.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_exception.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';
import 'package:popcorn_flutter/src/search/domain/media_watch_provider.dart';

/// [MediaSearchRepository] backed by The Movie Database (TMDB) REST API.
final class TmdbMediaSearchRepository implements MediaSearchRepository {
  TmdbMediaSearchRepository({required String accessToken, Uri? playerServerUrl, http.Client? client})
    // ignore: prefer_initializing_formals -- named parameters cannot be private.
    : _accessToken = accessToken,
      _playerServerUrl = playerServerUrl,
      _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _searchBaseUrl = '$_baseUrl/search';
  static const String _posterBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String _stillBaseUrl = 'https://image.tmdb.org/t/p/w300';
  static const String _profileBaseUrl = 'https://image.tmdb.org/t/p/w185';

  final String _accessToken;
  final Uri? _playerServerUrl;
  final http.Client _client;
  final Map<String, Future<MediaItem>> _mediaItemCache = {};

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
    final items = results.cast<Map<String, dynamic>>().map(_toMediaItem).toList(growable: false);
    return mediaType == MediaType.tv ? _includeLatestEpisodeMetadata(items) : items;
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
  Future<MediaItem> mediaItem(int id, MediaType mediaType) {
    final cacheKey = '${mediaType.name}:$id';
    final cached = _mediaItemCache[cacheKey];
    if (cached != null) return cached;

    final request = _fetchMediaItem(id, mediaType).then(
      (item) => item,
      onError: (Object error, StackTrace stackTrace) {
        _mediaItemCache.remove(cacheKey);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _mediaItemCache[cacheKey] = request;
    return request;
  }

  Future<MediaItem> _fetchMediaItem(int id, MediaType mediaType) async {
    final uri = Uri.parse('$_baseUrl/${_pathSegment(mediaType)}/$id');

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
    return _toMediaItem(decoded);
  }

  Future<List<MediaItem>> _includeLatestEpisodeMetadata(List<MediaItem> items) async {
    return Future.wait(
      items.map((item) async {
        if (item.latestSeasonAirDate != null || (item.latestEpisodeAirDate != null && item.latestEpisodeNumber == 1)) return item;

        try {
          final details = await mediaItem(item.id, MediaType.tv);
          return MediaItem(
            id: item.id,
            title: item.title,
            overview: item.overview,
            posterUrl: item.posterUrl,
            releaseDate: item.releaseDate,
            latestEpisodeAirDate: details.latestEpisodeAirDate ?? item.latestEpisodeAirDate,
            latestEpisodeNumber: details.latestEpisodeNumber ?? item.latestEpisodeNumber,
            latestSeasonAirDate: details.latestSeasonAirDate ?? item.latestSeasonAirDate,
            voteAverage: item.voteAverage,
          );
        } on MediaSearchException catch (error) {
          developer.log(
            'Could not load latest episode metadata for TV series ${item.id}',
            name: 'popcorn_flutter.search',
            error: error,
          );
          return item;
        }
      }),
    );
  }

  @override
  Future<MediaPerson> personDetails(int personId) async {
    final endpoint = Uri.parse('$_baseUrl/person/$personId');
    final uri = endpoint.replace(queryParameters: {'append_to_response': 'combined_credits'});

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB person request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB person request failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _toMediaPerson(decoded);
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
    final items = results.cast<Map<String, dynamic>>().map(_toMediaItem).toList(growable: false);
    return mediaType == MediaType.tv ? _includeLatestEpisodeMetadata(items) : items;
  }

  @override
  Future<List<MediaItem>> related(int id, MediaType mediaType) async {
    final uri = Uri.parse('$_baseUrl/${_pathSegment(mediaType)}/$id/recommendations');

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB recommendations request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB recommendations failed with status ${response.statusCode}');
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
  Future<List<MediaWatchProvider>> watchProviders(int id, MediaType mediaType, {required String region, String? title, int? year}) async {
    final uri = Uri.parse('$_baseUrl/${_pathSegment(mediaType)}/$id/watch/providers');
    final providerLinksFuture = title == null ? Future<Map<int, Uri>>.value(const {}) : _justWatchProviderLinks(title, mediaType, region, year);

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10), onTimeout: () => throw const MediaSearchException('TMDB watch providers request timeout'));
    } on SocketException catch (e) {
      throw MediaSearchException('Network error: Unable to reach TMDB. Please check your internet connection. ($e)');
    } catch (error) {
      throw MediaSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MediaSearchException('TMDB watch providers failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final countries = decoded['results'] as Map<String, dynamic>?;
    final availability = countries?[region.toUpperCase()] as Map<String, dynamic>?;
    if (availability == null) return const [];
    final justWatchUrl = Uri.tryParse(availability['link'] as String? ?? '');
    final validJustWatchUrl =
        justWatchUrl != null && justWatchUrl.scheme == 'https' && (justWatchUrl.host == 'www.justwatch.com' || justWatchUrl.host == 'justwatch.com')
        ? justWatchUrl
        : null;
    final providerLinks = await providerLinksFuture;

    const categories = ['flatrate', 'free', 'ads', 'rent', 'buy'];
    final seen = <int>{};
    final providers = <MediaWatchProvider>[];
    for (final category in categories) {
      final entries = availability[category] as List<dynamic>? ?? const [];
      for (final entry in entries.cast<Map<String, dynamic>>()) {
        final id = (entry['provider_id'] as num?)?.toInt();
        final logoPath = entry['logo_path'] as String?;
        final name = (entry['provider_name'] as String?)?.trim();
        if (id == null || logoPath == null || name == null || name.isEmpty || !seen.add(id)) continue;
        providers.add(
          MediaWatchProvider(
            id: id,
            name: name,
            logoUrl: Uri.parse('https://image.tmdb.org/t/p/w92$logoPath'),
            justWatchUrl: providerLinks[id] ?? validJustWatchUrl,
          ),
        );
      }
    }
    return List.unmodifiable(providers);
  }

  Future<Map<int, Uri>> _justWatchProviderLinks(String title, MediaType mediaType, String region, int? year) async {
    final serverUrl = _playerServerUrl;
    if (serverUrl == null) return const {};
    final query = <String, String>{'type': _pathSegment(mediaType), 'title': title, 'region': region};
    if (year != null) query['year'] = '$year';
    final endpoint = serverUrl.replace(path: '/watch-providers', queryParameters: query);
    try {
      final response = await _client.get(endpoint).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const {};
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const {};
      final links = <int, Uri>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        final url = entry.value is String ? Uri.tryParse(entry.value as String) : null;
        if (id != null && url != null && url.scheme == 'https' && (url.host == 'e.justwatch.com' || url.host == 'click.justwatch.com') && url.path == '/a') {
          links[id] = url;
        }
      }
      return links;
    } catch (_) {
      return const {};
    }
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
    final directors = _directors(json, mediaType);
    final director = directors.isEmpty ? null : directors.map((person) => person.name).join(', ');
    final castMembers = _cast(json);
    final cast = castMembers.map((member) => member.name).toList(growable: false);
    final status = MediaProductionStatus.fromTmdb(json['status'] as String?);
    switch (mediaType) {
      case MediaType.movie:
        final minutes = (json['runtime'] as num?)?.toInt();
        return MediaDetails(
          runtime: minutes == null || minutes <= 0 ? null : Duration(minutes: minutes),
          director: director,
          directors: directors,
          cast: cast,
          castMembers: castMembers,
          status: status,
        );
      case MediaType.tv:
        final seasonsJson = (json['seasons'] as List<dynamic>?) ?? const <dynamic>[];
        final seasons = seasonsJson.cast<Map<String, dynamic>>().map(_toMediaSeason).toList(growable: false);
        return MediaDetails(
          numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
          numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
          seasons: seasons,
          director: director,
          directors: directors,
          cast: cast,
          castMembers: castMembers,
          status: status,
        );
    }
  }

  /// Maximum number of leading cast members to surface on the details page.
  static const int _maxCastMembers = 5;

  /// Resolves the director of a movie (crew member with job `Director`) or the
  /// creator(s) of a TV series (`created_by`). Returns `null` when unknown.
  static List<CastMember> _directors(Map<String, dynamic> json, MediaType mediaType) {
    final crew = (json['credits'] as Map<String, dynamic>?)?['crew'] as List<dynamic>?;
    final directors = <CastMember>[];
    for (final member in (crew ?? const <dynamic>[]).cast<Map<String, dynamic>>()) {
      if (member['job'] == 'Director') {
        final id = (member['id'] as num?)?.toInt();
        final name = (member['name'] as String?)?.trim();
        if (id != null && name != null && name.isNotEmpty && !directors.any((person) => person.id == id)) {
          directors.add(CastMember(id: id, name: name));
        }
      }
    }
    if (directors.isEmpty && mediaType == MediaType.tv) {
      final creators = (json['created_by'] as List<dynamic>?) ?? const <dynamic>[];
      for (final creator in creators.cast<Map<String, dynamic>>()) {
        final id = (creator['id'] as num?)?.toInt();
        final name = (creator['name'] as String?)?.trim();
        if (id != null && name != null && name.isNotEmpty && !directors.any((person) => person.id == id)) {
          directors.add(CastMember(id: id, name: name));
        }
      }
    }
    return List.unmodifiable(directors);
  }

  /// Resolves the leading [_maxCastMembers] cast members, ordered by billing,
  /// each with the played character and a headshot when available.
  static List<CastMember> _cast(Map<String, dynamic> json) {
    final cast = (json['credits'] as Map<String, dynamic>?)?['cast'] as List<dynamic>?;
    final members = <CastMember>[];
    for (final member in (cast ?? const <dynamic>[]).cast<Map<String, dynamic>>()) {
      final name = (member['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final id = (member['id'] as num?)?.toInt();
      final character = (member['character'] as String?)?.trim();
      final profilePath = member['profile_path'] as String?;
      members.add(
        CastMember(
          id: id,
          name: name,
          character: character == null || character.isEmpty ? null : character,
          profileUrl: profilePath == null ? null : Uri.parse('$_profileBaseUrl$profilePath'),
        ),
      );
      if (members.length >= _maxCastMembers) break;
    }
    return List<CastMember>.unmodifiable(members);
  }

  MediaPerson _toMediaPerson(Map<String, dynamic> json) {
    final profilePath = json['profile_path'] as String?;
    final credits = json['combined_credits'] as Map<String, dynamic>?;
    final seen = <String>{};
    final knownFor = <PersonCredit>[];
    for (final category in ['cast', 'crew']) {
      final entries = credits?[category] as List<dynamic>? ?? const [];
      for (final entry in entries.cast<Map<String, dynamic>>()) {
        final typeName = entry['media_type'] as String?;
        final type = switch (typeName) {
          'movie' => MediaType.movie,
          'tv' => MediaType.tv,
          _ => null,
        };
        final id = entry['id'] as int?;
        if (type == null || id == null) continue;
        final role = ((category == 'cast' ? entry['character'] : entry['job']) as String?)?.trim();
        final genreIds = entry['genre_ids'] as List<dynamic>? ?? const <dynamic>[];
        final isTalkShow = genreIds.any((genreId) => genreId is num && genreId.toInt() == 10767);
        if (category == 'cast' && (_isSelfCredit(role) || isTalkShow)) continue;
        if (!seen.add('${type.name}:$id')) continue;
        final popularity = (entry['popularity'] as num?)?.toDouble() ?? 0;
        knownFor.add(PersonCredit(item: _toMediaItem(entry), type: type, role: role == null || role.isEmpty ? null : role, popularity: popularity));
      }
    }
    knownFor.sort((first, second) => second.popularity.compareTo(first.popularity));
    return MediaPerson(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      biography: (json['biography'] as String?) ?? '',
      birthday: _parseDate(json['birthday'] as String?),
      deathday: _parseDate(json['deathday'] as String?),
      placeOfBirth: json['place_of_birth'] as String?,
      knownForDepartment: json['known_for_department'] as String?,
      profileUrl: profilePath == null ? null : Uri.parse('$_profileBaseUrl$profilePath'),
      knownFor: List.unmodifiable(knownFor.take(20)),
    );
  }

  static bool _isSelfCredit(String? role) {
    if (role == null) return false;
    return RegExp(r'^(self|himself|herself|themselves)\b', caseSensitive: false).hasMatch(role.trim());
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
    final latestEpisode = json['last_episode_to_air'] as Map<String, dynamic>?;
    final seasons = (json['seasons'] as List<dynamic>?) ?? const <dynamic>[];
    final seasonAirDates = seasons.cast<Map<String, dynamic>>().where((season) {
      final seasonNumber = (season['season_number'] as num?)?.toInt() ?? 0;
      return seasonNumber > 0 && _parseDate(season['air_date'] as String?) != null;
    }).map((season) => _parseDate(season['air_date'] as String?)!);
    final latestSeasonAirDate = seasonAirDates.isEmpty ? null : seasonAirDates.reduce((first, second) => first.isAfter(second) ? first : second);
    return MediaItem(
      id: json['id'] as int,
      title: title,
      overview: (json['overview'] as String?) ?? '',
      posterUrl: posterPath == null ? null : Uri.parse('$_posterBaseUrl$posterPath'),
      releaseDate: _parseDate(releaseDate),
      latestEpisodeAirDate: _parseDate(latestEpisode?['air_date'] as String?),
      latestEpisodeNumber: (latestEpisode?['episode_number'] as num?)?.toInt(),
      latestSeasonAirDate: latestSeasonAirDate,
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
      publishedAt: _parseDate(json['published_at'] as String?),
    );
  }
}
