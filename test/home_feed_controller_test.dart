import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/home/view/browse_home_view.dart';
import 'package:popcorn_flutter/src/home/view/home_feed_controller.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';
import 'package:popcorn_flutter/src/search/infrastructure/tmdb_media_search_repository.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';

const _movie = MediaItem(id: 1, title: 'Movie', overview: '');
const _series = MediaItem(id: 1, title: 'Series', overview: '');

MediaVideo _video(String key, {String type = 'Trailer', String site = 'YouTube', String? date}) =>
    MediaVideo(id: key, key: key, name: key, site: site, type: type, publishedAt: date == null ? null : DateTime.parse(date));

class _Repository implements MediaSearchRepository {
  _Repository(this.loadVideos);

  final Future<List<MediaVideo>> Function(int, MediaType) loadVideos;

  @override
  Future<List<MediaItem>> trending(MediaType type) async => type == MediaType.movie ? [_movie] : [_series];

  @override
  Future<List<MediaVideo>> videos(int id, MediaType type) => loadVideos(id, type);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFavorites implements FavoritesRepository {
  @override
  Future<List<FavoriteMedia>> load() async => [];

  @override
  Future<void> save(List<FavoriteMedia> favorites) async {}
}

class _EmptyHistory implements WatchHistoryRepository {
  @override
  Future<List<WatchHistoryEntry>> load() async => [];

  @override
  Future<void> save(List<WatchHistoryEntry> entries) async {}
}

void main() {
  test('TMDB videos preserve publication timestamps', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/3/movie/1/videos');
      return http.Response(
        jsonEncode({
          'results': [
            {'id': 'trailer', 'key': 'key', 'site': 'YouTube', 'type': 'Trailer', 'published_at': '2026-10-01T12:00:00Z'},
          ],
        }),
        200,
      );
    });
    addTearDown(client.close);
    final repository = TmdbMediaSearchRepository(accessToken: 'test', client: client);
    final videos = await repository.videos(1, MediaType.movie);
    expect(videos.single.publishedAt, DateTime.utc(2026, 10, 1, 12));
  });

  test('selects the newest playable trailer per trending title and sorts by publication date', () async {
    final controller = HomeFeedController(
      repository: _Repository(
        (id, type) async => type == MediaType.movie
            ? [
                _video('old', date: '2026-01-01'),
                _video('new', date: '2026-09-01'),
                _video('clip', type: 'Clip', date: '2026-10-01'),
                _video('unsupported', site: 'Other', date: '2026-10-02'),
                _video('', date: '2026-10-03'),
              ]
            : [_video('tv', date: '2026-09-30')],
      ),
    );
    addTearDown(controller.dispose);
    await pumpEventQueue();

    expect(controller.trendingTrailers.map((entry) => entry.video.key), ['tv', 'new']);
    expect(controller.trendingTrailers.map((entry) => entry.type), [MediaType.tv, MediaType.movie]);
    expect(controller.hasError, isFalse);
  });

  test('failed video lookups do not hide the catalogue or other trailers', () async {
    final controller = HomeFeedController(
      repository: _Repository((id, type) async {
        if (type == MediaType.movie) throw StateError('Unavailable');
        return [_video('tv')];
      }),
    );
    addTearDown(controller.dispose);
    await pumpEventQueue();

    expect(controller.trendingMovies, [_movie]);
    expect(controller.trendingTrailers.single.video.key, 'tv');
    expect(controller.hasError, isFalse);
  });

  test('catalogue is ready before trailers and pending lookups can finish after disposal', () async {
    final pending = Completer<List<MediaVideo>>();
    final controller = HomeFeedController(repository: _Repository((id, type) => pending.future));
    await pumpEventQueue();

    expect(controller.isLoading, isFalse);
    expect(controller.trendingMovies, [_movie]);
    expect(controller.trendingTrailers, isEmpty);
    controller.dispose();
    pending.complete([_video('trailer')]);
    await pumpEventQueue();
    expect(controller.trendingTrailers, isEmpty);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('bottom trailer row opens the trailer player without playing the title at ${size.width}px', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository((id, type) async => [_video('Latest trailer', site: 'Vimeo')]);
      final feed = HomeFeedController(repository: repository);
      final favorites = FavoritesController(repository: _EmptyFavorites());
      final history = WatchHistoryController(repository: _EmptyHistory());
      final search = MediaSearchController(repository: repository);
      addTearDown(feed.dispose);
      addTearDown(favorites.dispose);
      addTearDown(history.dispose);
      addTearDown(search.dispose);
      await pumpEventQueue();
      MediaItem? playedItem;
      MediaType? playedType;
      MediaVideo? playedVideo;
      var detailsOpened = false;

      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => Scaffold(
              body: BrowseHomeView(
                feedController: feed,
                favoritesController: favorites,
                historyController: history,
                searchController: search,
                onOpenDetails: (item, type) => detailsOpened = true,
                onPlay: (item, type) {
                  playedItem = item;
                  playedType = type;
                },
                onResume: (_) {},
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.trailer,
            builder: (context, state) {
              playedVideo = state.extra as MediaVideo;
              return const Scaffold(body: Text('Trailer player'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Trending trailers'), findsOneWidget);
      final button = find.byTooltip('Play: Movie');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Trending trailers')).dy, greaterThan(tester.getTopLeft(find.text('Trending TV Series')).dy));
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Trailer player'), findsOneWidget);
      expect(playedVideo, same(feed.trendingTrailers.first.video));
      expect(playedItem, isNull);
      expect(playedType, isNull);
      expect(detailsOpened, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
