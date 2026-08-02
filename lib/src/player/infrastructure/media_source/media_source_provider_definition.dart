import 'dart:convert';
import 'dart:typed_data';

import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Declarative, JSON-decodable template describing how to build the HTTP
/// request for a streaming backend.
///
/// The definition holds no domain concepts of its own; it is a neutral request
/// blueprint covering the URL, method, query [parameters], [headers], [cookies]
/// and [body]. Dynamic parts are injected through placeholders substituted at
/// [buildRequest] time:
///   * `{id}`       -> the media identifier
///   * `{type}`     -> the media type (`movie` / `tv`)
///   * `{season}`   -> the TV season number (empty for movies)
///   * `{episode}`  -> the TV episode number (empty for movies)
///
/// Placeholders that resolve to an empty string produce empty URL path
/// segments, which are collapsed so a template like `/embed/{type}/{id}/{season}/{episode}`
/// yields `/embed/movie/123` for movies and `/embed/tv/123/1/1` for TV series.
final class MediaSourceProviderDefinition {
  const MediaSourceProviderDefinition({
    required this.name,
    required this.host,
    this.scheme = 'https',
    this.path = '',
    this.method = MediaSourceMethod.get,
    this.parameters = const <String, String>{},
    this.headers = const <String, String>{},
    this.cookies = const <MediaCookie>[],
    this.body,
  });

  /// Builds a definition from its JSON representation.
  ///
  /// Only [name] and [host] are required; every other part of the request
  /// defaults to an empty value.
  factory MediaSourceProviderDefinition.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final host = json['host'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('Media source provider definition requires a non-empty "name".');
    }
    if (host is! String || host.isEmpty) {
      throw const FormatException('Media source provider definition requires a non-empty "host".');
    }

    return MediaSourceProviderDefinition(
      name: name,
      host: host,
      scheme: json['scheme'] as String? ?? 'https',
      path: json['path'] as String? ?? '',
      method: _parseMethod(json['method']),
      parameters: _parseStringMap(json['parameters'], 'parameters'),
      headers: _parseStringMap(json['headers'], 'headers'),
      cookies: _parseCookies(json['cookies']),
      body: json['body'] as String?,
    );
  }

  /// Stable identifier used to select the active provider at runtime.
  final String name;

  /// The backend host, e.g. `web.nxsha.app`.
  final String host;

  /// URL scheme, defaulting to `https`.
  final String scheme;

  /// URL path template with `{id}`/`{type}`/`{season}`/`{episode}`
  /// placeholders, e.g. `/embed/{type}/{id}/{season}/{episode}`.
  final String path;

  /// HTTP method used for the request.
  final MediaSourceMethod method;

  /// Query parameters template; keys and values may contain placeholders.
  final Map<String, String> parameters;

  /// HTTP headers template; keys and values may contain placeholders.
  final Map<String, String> headers;

  /// Cookies template; any string field may contain placeholders.
  final List<MediaCookie> cookies;

  /// Optional request body template; may contain placeholders.
  final String? body;

  /// Builds a concrete [MediaSource] for [media]/[mediaType] by substituting
  /// every placeholder across the request template.
  ///
  /// [variables] supplies extra, externally-controlled placeholders (e.g. the
  /// `{language}`/`{subtitles}` playback preferences) that are substituted
  /// alongside the built-in `{id}` and `{type}`.
  ///
  /// For TV series, [season] and [episode] fill the `{season}`/`{episode}`
  /// placeholders, defaulting to `1` when omitted. For movies both resolve to
  /// an empty string and their (now empty) URL path segments are collapsed.
  MediaSource buildRequest(MediaItem media, MediaType mediaType, {Map<String, String> variables = const <String, String>{}, int? season, int? episode}) {
    final isSeries = mediaType == MediaType.tv;
    final seasonValue = isSeries ? '${season ?? 1}' : '';
    final episodeValue = isSeries ? '${episode ?? 1}' : '';

    String sub(String template) {
      var result = template
          .replaceAll('{id}', media.id.toString())
          .replaceAll('{type}', mediaType.name)
          .replaceAll('{season}', seasonValue)
          .replaceAll('{episode}', episodeValue);
      for (final entry in variables.entries) {
        result = result.replaceAll('{${entry.key}}', entry.value);
      }
      return result;
    }

    final resolvedParameters = parameters.map((key, value) => MapEntry(sub(key), sub(value)));
    final resolvedHeaders = headers.map((key, value) => MapEntry(sub(key), sub(value)));
    final resolvedCookies = cookies
        .map(
          (cookie) =>
              MediaCookie(name: sub(cookie.name), value: sub(cookie.value), domain: cookie.domain == null ? null : sub(cookie.domain!), path: sub(cookie.path)),
        )
        .toList(growable: false);
    final resolvedBody = body == null ? null : Uint8List.fromList(utf8.encode(sub(body!)));

    return MediaSource(
      url: Uri(scheme: scheme, host: host, path: _normalizePath(sub(path)), queryParameters: resolvedParameters.isEmpty ? null : resolvedParameters),
      method: method,
      headers: resolvedHeaders,
      cookies: resolvedCookies,
      body: resolvedBody,
    );
  }

  /// Removes empty path segments left behind by placeholders that resolved to
  /// an empty string (e.g. `{season}`/`{episode}` for movies), preserving the
  /// leading slash.
  static String _normalizePath(String path) {
    if (path.isEmpty) return path;
    final segments = path.split('/').where((segment) => segment.isNotEmpty);
    final normalized = segments.join('/');
    return path.startsWith('/') ? '/$normalized' : normalized;
  }

  static MediaSourceMethod _parseMethod(Object? raw) {
    if (raw == null) return MediaSourceMethod.get;
    final value = raw.toString().toUpperCase();
    return MediaSourceMethod.values.firstWhere((method) => method.value == value, orElse: () => throw FormatException('Unknown HTTP method "$raw".'));
  }

  static Map<String, String> _parseStringMap(Object? raw, String field) {
    if (raw == null) return const <String, String>{};
    if (raw is! Map) {
      throw FormatException('Media source provider "$field" must be a JSON object.');
    }
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  static List<MediaCookie> _parseCookies(Object? raw) {
    if (raw == null) return const <MediaCookie>[];
    if (raw is! List) {
      throw const FormatException('Media source provider "cookies" must be a JSON array.');
    }
    return raw
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException('Each media source cookie must be a JSON object.');
          }
          final cookieName = entry['name'];
          final cookieValue = entry['value'];
          if (cookieName is! String || cookieValue is! String) {
            throw const FormatException('Each media source cookie requires string "name" and "value".');
          }
          return MediaCookie(name: cookieName, value: cookieValue, domain: entry['domain'] as String?, path: entry['path'] as String? ?? '/');
        })
        .toList(growable: false);
  }
}
