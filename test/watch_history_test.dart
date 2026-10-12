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
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
          expect(saved!['profile_id'], 'profile-1');
          return http.Response('', 201, request: request);
        }
        expect(request.method, 'GET');
        expect(request.url.queryParameters['profile_id'], 'eq.profile-1');
        return http.Response(jsonEncode([saved]), 200, headers: {'content-type': 'application/json'}, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseWatchHistoryRepository(profileRepository: _Profiles(), client: client);
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
