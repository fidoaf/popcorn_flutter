import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/search/domain/movie.dart';
import 'package:popcorn_flutter/src/search/domain/movie_search_exception.dart';
import 'package:popcorn_flutter/src/search/domain/movie_search_repository.dart';

/// [MovieSearchRepository] backed by The Movie Database (TMDB) REST API.
final class TmdbMovieSearchRepository implements MovieSearchRepository {
  TmdbMovieSearchRepository({required String accessToken, http.Client? client})
    // ignore: prefer_initializing_formals -- named parameters cannot be private.
    : _accessToken = accessToken,
      _client = client ?? http.Client();

  static final Uri _searchEndpoint = Uri.parse('https://api.themoviedb.org/3/search/movie');
  static const String _posterBaseUrl = 'https://image.tmdb.org/t/p/w500';

  final String _accessToken;
  final http.Client _client;

  @override
  Future<List<Movie>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const <Movie>[];
    }

    final uri = _searchEndpoint.replace(queryParameters: {'query': trimmedQuery, 'include_adult': 'false'});

    final http.Response response;
    try {
      response = await _client.get(uri, headers: {'Authorization': 'Bearer $_accessToken', 'Accept': 'application/json'});
    } catch (error) {
      throw MovieSearchException('Unable to reach TMDB: $error');
    }

    if (response.statusCode != 200) {
      throw MovieSearchException('TMDB search failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>?) ?? const <dynamic>[];
    return results.cast<Map<String, dynamic>>().map(_toMovie).toList(growable: false);
  }

  Movie _toMovie(Map<String, dynamic> json) {
    final posterPath = json['poster_path'] as String?;
    return Movie(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      posterUrl: posterPath == null ? null : Uri.parse('$_posterBaseUrl$posterPath'),
      releaseDate: _parseDate(json['release_date'] as String?),
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
