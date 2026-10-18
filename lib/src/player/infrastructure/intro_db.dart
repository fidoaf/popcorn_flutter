import 'dart:convert';

import 'package:http/http.dart' as http;

final class SkipSegment {
  const SkipSegment({required this.start, this.end});

  final Duration start;
  final Duration? end;

  bool contains(Duration position) => position >= start && (end == null || position < end!);
}

final class IntroDbTimestamps {
  const IntroDbTimestamps({this.intros = const [], this.credits = const []});

  final List<SkipSegment> intros;
  final List<SkipSegment> credits;

  factory IntroDbTimestamps.fromJson(Map<String, dynamic> json) {
    List<SkipSegment> segments(String key) {
      final values = json[key];
      if (values == null) return const [];
      if (values is! List) throw FormatException('IntroDB $key must be an array');
      return values
          .map((value) {
            if (value is! Map) throw const FormatException('Invalid IntroDB segment');
            final start = value['start_ms'];
            final end = value['end_ms'];
            if ((start != null && (start is! num || !start.isFinite || start < 0)) ||
                (end != null && (end is! num || !end.isFinite || end < 0)) ||
                (start == null && end == null) ||
                (end is num && end <= (start ?? 0))) {
              throw const FormatException('Invalid IntroDB timestamps');
            }
            return SkipSegment(
              start: Duration(milliseconds: (start as num?)?.round() ?? 0),
              end: end == null ? null : Duration(milliseconds: (end as num).round()),
            );
          })
          .toList(growable: false);
    }

    return IntroDbTimestamps(intros: segments('intro'), credits: segments('credits'));
  }

  SkipSegment? introAt(Duration position, Duration duration) => intros.where((segment) => segment.end != null && segment.end! <= duration && segment.contains(position)).firstOrNull;

  bool creditsAt(Duration position) => credits.any((segment) => segment.contains(position));

  bool nextEpisodeAt(Duration position, Duration duration) =>
      creditsAt(position) || (credits.isEmpty && duration > Duration.zero && position >= Duration.zero && position <= duration && duration - position <= const Duration(seconds: 20));
}

Future<IntroDbTimestamps> loadIntroDbTimestamps({required int tmdbId, required Duration duration, int? season, int? episode, http.Client? client}) async {
  final uri = Uri.https('api.theintrodb.org', '/v3/media', {
    'tmdb_id': '$tmdbId',
    'duration_ms': '${duration.inMilliseconds}',
    if (season != null) 'season': '$season',
    if (episode != null) 'episode': '$episode',
  });
  final response = await (client == null ? http.get(uri) : client.get(uri)).timeout(const Duration(seconds: 10));
  if (response.statusCode == 404) return const IntroDbTimestamps();
  if (response.statusCode != 200) throw http.ClientException('IntroDB request failed (${response.statusCode})', uri);
  final json = jsonDecode(response.body);
  if (json is! Map<String, dynamic>) throw const FormatException('Invalid IntroDB response');
  return IntroDbTimestamps.fromJson(json);
}
