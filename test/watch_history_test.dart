import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:popcorn_flutter/src/history/infrastructure/supabase_watch_history_repository.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session_scope.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/stream_resolver.dart';
import 'package:popcorn_flutter/src/profile/domain/profile.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('player event scope refreshes when only the media identity changes', (tester) async {
    PlaybackSessionScope? current;
    final saved = <PlaybackSession>[];
    final child = Builder(
      builder: (context) {
        current = PlaybackSessionScope.of(context);
        return const SizedBox();
      },
    );
    Widget scope(int id) => PlaybackSessionScope(initial: const PlaybackSession(), mediaId: id, mediaType: 'movie', onChanged: saved.add, child: child);
    await tester.pumpWidget(scope(42));
    expect(current!.mediaId, 42);
    await tester.pumpWidget(scope(43));
    expect(current!.mediaId, 43);
    current!.accept({
      'type': 'popcorn:playback',
      'media': {'type': 'movie', 'id': '43'},
      'session': {'positionSeconds': 300},
    });
    expect(saved.single.positionSeconds, 300);
  });

  test('five-second player progress updates reach the history table through five minutes', () async {
    final savedPositions = <double>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') return http.Response('[]', 200, headers: {'content-type': 'application/json'}, request: request);
        final row = jsonDecode(request.body) as Map;
        savedPositions.add((row['position_seconds'] as num).toDouble());
        return http.Response('', 201, request: request);
      }),
    );
    addTearDown(client.dispose);
    final controller = WatchHistoryController(
      repository: SupabaseWatchHistoryRepository(profileRepository: _Profiles(), mediaRepository: _Catalog(), client: client),
    );
    await controller.ready;
    addTearDown(controller.dispose);
    const item = MediaItem(id: 42, title: 'Movie', overview: '');
    final writes = <Future<void>>[];
    final scope = PlaybackSessionScope(
      initial: const PlaybackSession(),
      mediaId: 42,
      mediaType: 'movie',
      onChanged: (session) => writes.add(controller.record(item, MediaType.movie, playback: session)),
      child: const SizedBox(),
    );
    for (var seconds = 5; seconds <= 300; seconds += 5) {
      scope.accept({
        'type': 'popcorn:playback',
        'event': 'progress',
        'media': {'type': 'movie', 'id': '42', 'season': '0', 'episode': '0'},
        'session': {'provider': 'vidsrcbuzz', 'positionSeconds': seconds},
      });
    }
    await Future.wait(writes);
    expect(savedPositions, [for (var seconds = 5; seconds <= 300; seconds += 5) seconds.toDouble()]);
    expect(controller.entries.single.playback.positionSeconds, 300);
  });

  test('database write failures propagate instead of reporting successful progress saves', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => request.method == 'GET'
            ? http.Response('[]', 200, headers: {'content-type': 'application/json'}, request: request)
            : http.Response(
                jsonEncode({'code': '23502', 'message': 'null value in column "title" violates not-null constraint'}),
                400,
                headers: {'content-type': 'application/json'},
                request: request,
              ),
      ),
    );
    addTearDown(client.dispose);
    final controller = WatchHistoryController(
      repository: SupabaseWatchHistoryRepository(profileRepository: _Profiles(), mediaRepository: _Catalog(), client: client),
    );
    await controller.ready;
    addTearDown(controller.dispose);
    await expectLater(
      controller.record(
        const MediaItem(id: 42, title: 'Movie', overview: ''),
        MediaType.movie,
        playback: const PlaybackSession(positionSeconds: 300),
      ),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('history loads catalog metadata and caches movie and TV identities separately', () async {
    final catalog = _Catalog();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final columns = request.url.queryParameters['select']!.split(',');
        for (final column in ['title', 'overview', 'poster_url', 'release_date', 'vote_average']) {
          expect(columns, isNot(contains(column)));
        }
        return http.Response(
          jsonEncode([
            {'media_id': 42, 'media_type': 'movie', 'position_seconds': 120, 'title': 'Stale stored title'},
            {'media_id': 42, 'media_type': 'tv', 'season': 2, 'episode': 3, 'position_seconds': 240},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseWatchHistoryRepository(profileRepository: _Profiles(), mediaRepository: catalog, client: client);
    final entries = await repository.load();
    expect(entries.map((entry) => entry.item.title), ['Movie', 'Series']);
    expect(entries.first.item.overview, 'Catalog overview');
    expect(entries.first.item.posterUrl, Uri.parse('https://catalog.example/movie/42.jpg'));
    expect(entries.first.playback.positionSeconds, 120);
    expect(entries.last.season, 2);
    expect(entries.last.episode, 3);
    expect(entries.last.playback.positionSeconds, 240);
    expect(catalog.requests, [(MediaType.movie, 42), (MediaType.tv, 42)]);
    await repository.load();
    expect(catalog.requests.length, 2);
  });

  test('failed catalog lookup retains resume data and retries on the next load', () async {
    final catalog = _Catalog(fail: true);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'media_id': 42,
              'media_type': 'tv',
              'season': 2,
              'episode': 3,
              'position_seconds': 123.5,
              'playback_provider': 'vidsrcbuzz',
              'subtitle_selection': '',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabaseWatchHistoryRepository(profileRepository: _Profiles(), mediaRepository: catalog, client: client);
    final fallback = (await repository.load()).single;
    expect(fallback.item.id, 42);
    expect(fallback.item.title, 'tv 42');
    expect(fallback.season, 2);
    expect(fallback.episode, 3);
    expect(fallback.playback.positionSeconds, 123.5);
    expect(fallback.playback.provider, 'vidsrcbuzz');
    expect(fallback.playback.subtitles, '');
    catalog.fail = false;
    expect((await repository.load()).single.item.title, 'Series');
    expect(catalog.requests.length, 2);
  });

  test('Supabase round-trips individual playback columns without a JSONB snapshot', () async {
    Map<String, dynamic>? saved;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/watch_history');
        if (request.method == 'POST') {
          expect(request.url.queryParameters['on_conflict'], 'profile_id,media_type,media_id');
          saved = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          expect(saved!.containsKey('playback'), isFalse);
          for (final column in ['title', 'overview', 'poster_url', 'release_date', 'vote_average']) {
            expect(saved!.containsKey(column), isFalse);
          }
          expect(saved!['profile_id'], 'profile-1');
          return http.Response('', 201, request: request);
        }
        expect(request.method, 'GET');
        expect(request.url.queryParameters['profile_id'], 'eq.profile-1');
        return http.Response(jsonEncode([saved]), 200, headers: {'content-type': 'application/json'}, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseWatchHistoryRepository(profileRepository: _Profiles(), mediaRepository: _Catalog(), client: client);
    for (final subtitles in ['', null, '["Spanish","es"]']) {
      final playback = PlaybackSession(provider: 'vidsrcbuzz', source: '["Server 1","Spanish"]', language: 'es', subtitles: subtitles, positionSeconds: 123.5);
      await repository.upsert(
        WatchHistoryEntry(
          item: const MediaItem(id: 42, title: 'Movie', overview: ''),
          type: MediaType.movie,
          watchedAt: DateTime.utc(2026),
          playback: playback,
        ),
      );
      expect(saved!['playback_provider'], playback.provider);
      expect(saved!['playback_source'], playback.source);
      expect(saved!['audio_language'], playback.language);
      expect(saved!['subtitle_selection'], subtitles);
      expect(saved!['position_seconds'], 123.5);
      expect((await repository.load()).single.playback.toJson(), playback.toJson());
    }
    await repository.upsert(
      WatchHistoryEntry(
        item: const MediaItem(id: 42, title: 'Movie', overview: ''),
        type: MediaType.movie,
        watchedAt: DateTime.utc(2026),
      ),
    );
    expect(saved!['position_seconds'], 0);
    expect((await repository.load()).single.playback.toJson(), const PlaybackSession().toJson());
  });

  test('watch history preserves the playback session across serialization', () {
    final entry = WatchHistoryEntry(
      item: const MediaItem(id: 42, title: 'Movie', overview: ''),
      type: MediaType.movie,
      watchedAt: DateTime.utc(2026),
      playback: const PlaybackSession(provider: 'vidsrcbuzz', source: 'Server 1', language: 'es', subtitles: 'Spanish', positionSeconds: 123.5),
    );
    final restored = WatchHistoryEntry.fromJson(entry.toJson());
    expect(restored.playback.toJson(), entry.playback.toJson());
    final legacy = entry.toJson()..remove('playback');
    expect(WatchHistoryEntry.fromJson(legacy).playback.positionSeconds, 0);
  });

  test('invalid playback positions are discarded', () {
    for (final position in [-1.0, double.nan, double.infinity]) {
      expect(PlaybackSession.fromJson({'positionSeconds': position}).positionSeconds, 0);
    }
  });

  test('session events reject other titles, episodes and malformed settings', () {
    final sessions = <PlaybackSession>[];
    final scope = PlaybackSessionScope(
      initial: const PlaybackSession(),
      onChanged: sessions.add,
      mediaId: 42,
      mediaType: 'tv',
      season: 1,
      episode: 2,
      child: const SizedBox(),
    );
    Map<String, dynamic> event({int id = 42, int episode = 2, dynamic provider = 'vidsrcbuzz'}) => {
      'type': 'popcorn:playback',
      'media': {'type': 'tv', 'id': '$id', 'season': '1', 'episode': '$episode'},
      'session': {'provider': provider, 'positionSeconds': 120},
    };
    scope.accept(event(id: 99));
    scope.accept(event(episode: 3));
    scope.accept(event(provider: 123));
    scope.accept(null);
    expect(sessions, isEmpty);
    scope.accept(event());
    expect(sessions.single.positionSeconds, 120);
  });

  test('record preserves an existing episode session and resets a new episode', () async {
    final repository = _MemoryHistory();
    final controller = WatchHistoryController(repository: repository);
    await controller.ready;
    const media = MediaItem(id: 42, title: 'Series', overview: '');
    await controller.record(media, MediaType.tv, season: 1, episode: 2, playback: const PlaybackSession(positionSeconds: 200));
    await controller.record(media, MediaType.tv, season: 1, episode: 2);
    expect(controller.entries.single.playback.positionSeconds, 200);
    await controller.record(media, MediaType.tv, season: 1, episode: 3);
    expect(controller.entries.single.playback.positionSeconds, 0);
    expect(repository.entries.single.episode, 3);
    await controller.remove(MediaType.tv, 42);
    expect(repository.entries, isEmpty);
    controller.dispose();
  });

  test('a fresh device controller loads the saved playback snapshot', () async {
    final repository = _MemoryHistory();
    final firstDevice = WatchHistoryController(repository: repository);
    await firstDevice.ready;
    await firstDevice.record(
      const MediaItem(id: 42, title: 'Movie', overview: ''),
      MediaType.movie,
      playback: const PlaybackSession(provider: 'onlypelis', source: 'Server 1', language: 'fr', subtitles: '', positionSeconds: 455),
    );
    final secondDevice = WatchHistoryController(repository: repository);
    await secondDevice.ready;
    expect(secondDevice.entries.single.playback.toJson(), firstDevice.entries.single.playback.toJson());
    firstDevice.dispose();
    secondDevice.dispose();
  });

  test('native hosted playback resolves to a manifest without bridge parameters', () async {
    final source = MediaSource(
      url: Uri.parse('https://player.example/player?id=42&type=movie&provider=onlypelis&lang=fr&sub=0&resume=120&parentOrigin=https%3A%2F%2Fapp.example'),
    );
    final candidates = await StreamResolver.resolve(source);
    expect(candidates.single.url.path, '/manifest');
    expect(candidates.single.url.queryParameters, {'id': '42', 'type': 'movie', 'provider': 'onlypelis', 'lang': 'fr', 'sub': '0'});
    expect(candidates.single.sourceName, '');
  });
}

class _MemoryHistory implements WatchHistoryRepository {
  final entries = <WatchHistoryEntry>[];

  @override
  Future<List<WatchHistoryEntry>> load() async => List.of(entries);

  @override
  Future<void> upsert(WatchHistoryEntry entry) async {
    entries.removeWhere((existing) => existing.matches(entry.type, entry.item.id));
    entries.add(entry);
  }

  @override
  Future<void> remove(WatchHistoryEntry entry) async => entries.removeWhere((existing) => existing.matches(entry.type, entry.item.id));
}

class _Profiles implements ProfileRepository {
  @override
  Future<Profile?> activeProfile() async => const Profile(id: 'profile-1', accountId: 'account-1', displayName: 'Viewer');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements MediaSearchRepository {
  _Catalog({this.fail = false});

  bool fail;
  final requests = <(MediaType, int)>[];

  @override
  Future<MediaItem> mediaItem(int id, MediaType mediaType) async {
    requests.add((mediaType, id));
    if (fail) throw StateError('Catalog unavailable');
    return MediaItem(
      id: id,
      title: mediaType == MediaType.movie ? 'Movie' : 'Series',
      overview: 'Catalog overview',
      posterUrl: Uri.parse('https://catalog.example/${mediaType.name}/$id.jpg'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
