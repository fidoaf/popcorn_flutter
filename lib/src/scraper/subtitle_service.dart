import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/scraper/subtitle_models.dart';

/// A framework-agnostic Dart port of the subtitle-related logic from the
/// original Node/Express VidSrc scraper server.
///
/// It reimplements these server responsibilities without any headless browser:
///  * TMDB -> IMDb id resolution (`getIMDbIdFromTMDB`)
///  * OpenSubtitles search (`searchSubtitles`)
///  * OpenSubtitles download-link resolution (`getSubtitleDownloadUrl`)
///  * the `/movie-subtitles` and `/tv-subtitles` orchestration
///  * the `/subtitle-proxy` SRT -> VTT conversion
///
/// The `/extract` endpoint from the server is intentionally omitted: it relied
/// on Playwright driving a headless browser to intercept `.m3u8`/subtitle
/// network traffic, which has no pure-Dart equivalent.
class SubtitleService {
  SubtitleService({required String tmdbApiKey, required String openSubtitlesApiKey, String userAgent = 'Cinemi v1.0.0', http.Client? httpClient})
    : _tmdbApiKey = tmdbApiKey,
      _openSubtitlesApiKey = openSubtitlesApiKey,
      _userAgent = userAgent,
      _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final String _tmdbApiKey;
  final String _openSubtitlesApiKey;
  final String _userAgent;
  final http.Client _client;
  final bool _ownsClient;

  static const String _tmdbBase = 'https://api.themoviedb.org/3';
  static const String _openSubtitlesBase = 'https://api.opensubtitles.com/api/v1';

  /// Resolves the IMDb id for a TMDB [tmdbId]. [type] is `movie` or `tv`.
  ///
  /// Returns `null` when TMDB has no IMDb mapping. Mirrors
  /// `getIMDbIdFromTMDB`.
  Future<String?> getImdbIdFromTmdb(String tmdbId, {String type = 'movie'}) async {
    final Uri uri = Uri.parse('$_tmdbBase/$type/$tmdbId/external_ids?api_key=$_tmdbApiKey');
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const SubtitleException('Failed to fetch IMDb ID from TMDB');
    }
    final Map<String, Object?> json = jsonDecode(response.body) as Map<String, Object?>;
    final Object? imdbId = json['imdb_id'];
    return imdbId is String && imdbId.isNotEmpty ? imdbId : null;
  }

  /// Searches OpenSubtitles for the given [imdbId] and returns up to two
  /// candidates in the supported languages, ordered by download count.
  ///
  /// Mirrors `searchSubtitles` (movies: page 1 only).
  Future<List<SubtitleCandidate>> searchSubtitles(String imdbId) async {
    final Uri uri = Uri.parse('$_openSubtitlesBase/subtitles?imdb_id=$imdbId&per_page=100&page=1');
    final http.Response response = await _client.get(uri, headers: _openSubtitlesHeaders());
    if (response.statusCode != 200) {
      // Matches server behaviour: a failed search yields no subtitles.
      return const <SubtitleCandidate>[];
    }
    final Map<String, Object?> json = jsonDecode(response.body) as Map<String, Object?>;
    final List<Object?> data = (json['data'] as List<Object?>?) ?? const <Object?>[];
    if (data.isEmpty) {
      return const <SubtitleCandidate>[];
    }

    final List<SubtitleCandidate> candidates = <SubtitleCandidate>[];
    for (final Object? entry in data) {
      final Map<String, Object?>? attributes = (entry as Map<String, Object?>?)?['attributes'] as Map<String, Object?>?;
      if (attributes == null) {
        continue;
      }
      final int? fileId = _firstFileId(attributes);
      final Object? language = attributes['language'];
      if (fileId == null || language is! String || !commonLanguages.contains(language)) {
        continue;
      }
      candidates.add(
        SubtitleCandidate(
          language: language,
          languageName: languageNames[language] ?? language,
          fileId: fileId,
          downloadCount: (attributes['download_count'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    candidates.sort((SubtitleCandidate a, SubtitleCandidate b) => b.downloadCount.compareTo(a.downloadCount));
    return candidates.take(2).toList();
  }

  /// Exchanges an OpenSubtitles [fileId] for a temporary download URL.
  ///
  /// Mirrors `getSubtitleDownloadUrl`.
  Future<String> getSubtitleDownloadUrl(int fileId) async {
    final http.Response response = await _client.post(
      Uri.parse('$_openSubtitlesBase/download'),
      headers: <String, String>{'Content-Type': 'application/json', ..._openSubtitlesHeaders()},
      body: jsonEncode(<String, Object?>{'file_id': fileId}),
    );
    if (response.statusCode != 200) {
      throw SubtitleException('Subtitle download URL fetch failed: ${response.body}');
    }
    final Map<String, Object?> json = jsonDecode(response.body) as Map<String, Object?>;
    final Object? link = json['link'];
    if (link is! String) {
      throw const SubtitleException('Subtitle download URL missing from response');
    }
    return link;
  }

  /// Full `/movie-subtitles` flow: TMDB -> IMDb -> OpenSubtitles search ->
  /// resolve download links.
  ///
  /// Throws [SubtitleException] (with a [SubtitleException.statusCode]) when the
  /// IMDb id cannot be resolved, mirroring the server's 404.
  Future<MovieSubtitlesResult> getMovieSubtitles(String tmdbId, {String type = 'movie'}) async {
    final String? imdbId = await getImdbIdFromTmdb(tmdbId, type: type);
    if (imdbId == null) {
      throw const SubtitleException('IMDb ID not found', statusCode: 404);
    }

    final List<SubtitleCandidate> candidates = await searchSubtitles(imdbId);
    final List<SubtitleTrack?> resolved = await Future.wait(
      candidates.map((SubtitleCandidate candidate) async {
        try {
          final String url = await getSubtitleDownloadUrl(candidate.fileId);
          return SubtitleTrack(language: candidate.language, languageName: candidate.languageName, url: url);
        } on Object {
          return null;
        }
      }),
    );

    return MovieSubtitlesResult(subtitles: resolved.whereType<SubtitleTrack>().toList(), tmdbId: tmdbId, imdbId: imdbId, type: type);
  }

  /// `/tv-subtitles` equivalent: returns a WEBVTT document for a TV episode.
  ///
  /// The original server delegated to a `getTVSubtitleVTT` helper that is not
  /// part of this attachment. This reimplementation queries OpenSubtitles by
  /// the show's TMDB id plus [season]/[episode], downloads the best match and
  /// converts it to VTT. Returns `null` when no subtitle is found.
  Future<String?> getTvSubtitleVtt(String showTmdbId, {required int season, required int episode}) async {
    final Uri uri = Uri.parse(
      '$_openSubtitlesBase/subtitles'
      '?parent_tmdb_id=$showTmdbId&season_number=$season&episode_number=$episode'
      '&languages=${commonLanguages.join(',')}&per_page=100&page=1',
    );
    final http.Response response = await _client.get(uri, headers: _openSubtitlesHeaders());
    if (response.statusCode != 200) {
      return null;
    }

    final Map<String, Object?> json = jsonDecode(response.body) as Map<String, Object?>;
    final List<Object?> data = (json['data'] as List<Object?>?) ?? const <Object?>[];

    int? bestFileId;
    int bestDownloads = -1;
    for (final Object? entry in data) {
      final Map<String, Object?>? attributes = (entry as Map<String, Object?>?)?['attributes'] as Map<String, Object?>?;
      if (attributes == null) {
        continue;
      }
      final int? fileId = _firstFileId(attributes);
      final int downloads = (attributes['download_count'] as num?)?.toInt() ?? 0;
      if (fileId != null && downloads > bestDownloads) {
        bestFileId = fileId;
        bestDownloads = downloads;
      }
    }

    if (bestFileId == null) {
      return null;
    }

    final String downloadUrl = await getSubtitleDownloadUrl(bestFileId);
    return convertToVtt(downloadUrl);
  }

  /// `/subtitle-proxy` equivalent: downloads the subtitle at [fileUrl] and
  /// returns it as a WEBVTT document, converting SRT timecodes when needed.
  Future<String> convertToVtt(String fileUrl) async {
    final http.Response response = await _client.get(Uri.parse(fileUrl));
    if (response.statusCode != 200) {
      throw const SubtitleException('Failed to download subtitle for conversion');
    }
    return srtToVtt(response.body);
  }

  /// Pure SRT -> VTT string conversion, mirroring the server's inline logic.
  static String srtToVtt(String srt) {
    final String normalised = srt.replaceAll(RegExp(r'\r+'), '').trim();
    final Iterable<String> lines = normalised
        .split('\n')
        .map((String line) => line.replaceAllMapped(RegExp(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})'), (Match m) => '${m[1]}:${m[2]}:${m[3]}.${m[4]}'));
    return 'WEBVTT\n\n${lines.join('\n')}';
  }

  /// Releases the underlying [http.Client] when this service created it.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Map<String, String> _openSubtitlesHeaders() => <String, String>{'Api-Key': _openSubtitlesApiKey, 'User-Agent': _userAgent};

  /// Extracts `attributes.files[0].file_id` when present.
  static int? _firstFileId(Map<String, Object?> attributes) {
    final List<Object?>? files = attributes['files'] as List<Object?>?;
    if (files == null || files.isEmpty) {
      return null;
    }
    final Object? fileId = (files.first as Map<String, Object?>?)?['file_id'];
    return (fileId as num?)?.toInt();
  }
}
