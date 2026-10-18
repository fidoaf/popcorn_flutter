import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session_scope.dart';
import 'package:popcorn_flutter/src/player/infrastructure/intro_db.dart';
import 'package:popcorn_flutter/src/player/infrastructure/next_episode.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_episode.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

void main() {
  test('next action label reflects season rollover and scope notifies on target changes', () {
    PlaybackSessionScope scope(int? nextSeason) => PlaybackSessionScope(
      initial: const PlaybackSession(),
      mediaId: 42,
      mediaType: 'tv',
      season: 1,
      episode: 2,
      nextSeason: nextSeason,
      onChanged: _ignoreSession,
      child: const SizedBox(),
    );
    expect(scope(1).nextEpisodeLabel, 'Next episode');
    expect(scope(2).nextEpisodeLabel, 'Next season');
    expect(scope(null).nextEpisodeLabel, 'Next episode');
    expect(scope(2).updateShouldNotify(scope(1)), isTrue);
    expect(scope(1).updateShouldNotify(scope(1)), isFalse);
  });

  test('next episode falls back to the final 20 seconds only without credits timestamps', () {
    const missing = IntroDbTimestamps();
    const duration = Duration(seconds: 100);
    expect(missing.nextEpisodeAt(const Duration(milliseconds: 79999), duration), isFalse);
    expect(missing.nextEpisodeAt(const Duration(seconds: 80), duration), isTrue);
    expect(missing.nextEpisodeAt(duration, duration), isTrue);
    expect(missing.nextEpisodeAt(const Duration(milliseconds: 100001), duration), isFalse);
    expect(missing.nextEpisodeAt(Duration.zero, Duration.zero), isFalse);
    expect(missing.nextEpisodeAt(const Duration(seconds: -1), duration), isFalse);
    expect(missing.nextEpisodeAt(Duration.zero, const Duration(seconds: 15)), isTrue);
    final known = IntroDbTimestamps.fromJson({
      'credits': [
        {'start_ms': 50000, 'end_ms': 60000},
      ],
    });
    expect(known.nextEpisodeAt(const Duration(seconds: 50), duration), isTrue);
    expect(known.nextEpisodeAt(const Duration(seconds: 80), duration), isFalse);
  });

  test('IntroDB uses v3, TMDB identity, episode and actual duration', () async {
    final client = MockClient((request) async {
      expect(request.url.origin, 'https://api.theintrodb.org');
      expect(request.url.path, '/v3/media');
      expect(request.url.queryParameters, {'tmdb_id': '1399', 'season': '2', 'episode': '3', 'duration_ms': '2700000'});
      return http.Response(
        jsonEncode({
          'intro': [
            {'start_ms': null, 'end_ms': 23000},
          ],
          'credits': [
            {'start_ms': 2600000, 'end_ms': null},
          ],
        }),
        200,
      );
    });
    final data = await loadIntroDbTimestamps(tmdbId: 1399, season: 2, episode: 3, duration: const Duration(minutes: 45), client: client);
    expect(data.introAt(Duration.zero, const Duration(minutes: 45))?.end, const Duration(seconds: 23));
    expect(data.introAt(const Duration(seconds: 23), const Duration(minutes: 45)), isNull);
    expect(data.creditsAt(const Duration(milliseconds: 2599999)), isFalse);
    expect(data.creditsAt(const Duration(milliseconds: 2600000)), isTrue);
  });

  test('multiple ranges use inclusive start and exclusive end; unknown intro end cannot seek', () {
    final data = IntroDbTimestamps.fromJson({
      'intro': [
        {'start_ms': 10000, 'end_ms': 20000},
        {'start_ms': 30000, 'end_ms': 40000},
        {'start_ms': 50000, 'end_ms': null},
      ],
      'credits': [
        {'start_ms': 80000, 'end_ms': 90000},
        {'start_ms': 95000, 'end_ms': null},
      ],
    });
    const duration = Duration(seconds: 100);
    expect(data.introAt(const Duration(milliseconds: 9999), duration), isNull);
    expect(data.introAt(const Duration(seconds: 10), duration), isNotNull);
    expect(data.introAt(const Duration(seconds: 20), duration), isNull);
    expect(data.introAt(const Duration(seconds: 30), duration)?.end, const Duration(seconds: 40));
    expect(data.introAt(const Duration(seconds: 30), const Duration(seconds: 35)), isNull);
    expect(data.introAt(const Duration(seconds: 50), duration), isNull);
    expect(data.creditsAt(const Duration(seconds: 80)), isTrue);
    expect(data.creditsAt(const Duration(seconds: 90)), isFalse);
    expect(data.creditsAt(const Duration(seconds: 95)), isTrue);
  });

  test('missing timestamps are normal, API and malformed data failures are explicit', () async {
    final missing = await loadIntroDbTimestamps(tmdbId: 42, duration: const Duration(minutes: 1), client: MockClient((_) async => http.Response('', 404)));
    expect(missing.intros, isEmpty);
    await expectLater(loadIntroDbTimestamps(tmdbId: 42, duration: const Duration(minutes: 1), client: MockClient((_) async => http.Response('', 503))), throwsA(isA<http.ClientException>()));
    for (final segment in [
      {'start_ms': -1, 'end_ms': 100},
      {'start_ms': 200, 'end_ms': 100},
      {'start_ms': null, 'end_ms': null},
      {'start_ms': null, 'end_ms': 0},
      {'start_ms': '100', 'end_ms': 200},
    ]) {
      expect(
        () => IntroDbTimestamps.fromJson({
          'intro': [segment],
        }),
        throwsFormatException,
      );
    }
  });

  test('next episode resolves same season, rollover, finales and unreleased episodes', () async {
    final catalog = _Catalog({
      1: [_episode(1), _episode(2)],
      2: [_episode(1), _episode(2, released: false)],
    });
    expect(await findNextEpisode(catalog, 42, 1, 1), (1, 2));
    expect(await findNextEpisode(catalog, 42, 1, 2), (2, 1));
    expect(await findNextEpisode(catalog, 42, 2, 1), isNull);
    expect(await findNextEpisode(catalog, 42, 2, 2), isNull);
  });

  test('next action saves session first and rejects stale or foreign episode events', () {
    final calls = <String>[];
    final scope = PlaybackSessionScope(
      initial: const PlaybackSession(),
      mediaId: 42,
      mediaType: 'tv',
      season: 1,
      episode: 2,
      onChanged: (PlaybackSession session) => calls.add('save:${session.positionSeconds}'),
      onNextEpisode: () => calls.add('next'),
      child: const SizedBox(),
    );
    Map<String, dynamic> message(int id, int episode) => {
      'type': 'popcorn:next',
      'media': {'id': id, 'type': 'tv', 'season': 1, 'episode': episode},
      'session': {'positionSeconds': 90},
    };
    scope.accept(message(43, 2));
    scope.accept(message(42, 1));
    expect(calls, isEmpty);
    scope.accept(message(42, 2));
    expect(calls, ['save:90.0', 'next']);
  });
}

void _ignoreSession(PlaybackSession session) {}

MediaEpisode _episode(int number, {bool released = true}) => MediaEpisode(episodeNumber: number, name: '', airDate: released ? DateTime(2020) : DateTime(2100));

class _Catalog implements MediaSearchRepository {
  _Catalog(this.seasons);
  final Map<int, List<MediaEpisode>> seasons;

  @override
  Future<List<MediaEpisode>> episodes(int seriesId, int seasonNumber) async => seasons[seasonNumber] ?? [];

  @override
  Future<MediaDetails> details(int id, MediaType mediaType) async => MediaDetails(
    seasons: seasons.keys.map((number) => MediaSeason(seasonNumber: number, name: '')).toList(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
