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
  _Repository(
    this.loadVideos, {
    this.movies = const [_movie],
    this.tvSeries = const [_series],
    this.movieSearchResults = const [_movie],
    this.tvSearchResults = const [_series],
  });

  final Future<List<MediaVideo>> Function(int, MediaType) loadVideos;
  final List<MediaItem> movies;
  final List<MediaItem> tvSeries;
  final List<MediaItem> movieSearchResults;
  final List<MediaItem> tvSearchResults;

  @override
  Future<List<MediaItem>> trending(MediaType type) async => type == MediaType.movie ? movies : tvSeries;

  @override
  Future<List<MediaItem>> search(String query, MediaType mediaType) async => mediaType == MediaType.movie ? movieSearchResults : tvSearchResults;

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
  _EmptyHistory({this.entries = const []});

  final List<WatchHistoryEntry> entries;

  @override
  Future<List<WatchHistoryEntry>> load() async => entries;

  @override
  Future<void> upsert(WatchHistoryEntry entry) async {}

  @override
  Future<void> remove(WatchHistoryEntry entry) async {}
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

  test('TMDB TV trending and search results load latest episode metadata', () async {
    final latestEpisodeAirDate = DateTime.now().subtract(const Duration(days: 7));
    final futureSeasonAirDate = DateTime.now().add(const Duration(days: 90));
    var detailRequests = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/3/trending/tv/week':
        case '/3/search/tv':
          return http.Response(
            jsonEncode({
              'results': [
                {'id': 1, 'name': 'Series', 'first_air_date': '2020-01-01'},
              ],
            }),
            200,
          );
        case '/3/tv/1':
          detailRequests++;
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'Series',
              'first_air_date': '2020-01-01',
              'last_episode_to_air': {'air_date': latestEpisodeAirDate.toIso8601String(), 'episode_number': 2},
              'seasons': [
                {'season_number': 0, 'air_date': latestEpisodeAirDate.toIso8601String()},
                {'season_number': 1, 'air_date': latestEpisodeAirDate.toIso8601String()},
                {'season_number': 2, 'air_date': futureSeasonAirDate.toIso8601String()},
              ],
              'number_of_seasons': 2,
            }),
            200,
          );
        default:
          throw StateError('Unexpected TMDB request: ${request.url}');
      }
    });
    addTearDown(client.close);
    final repository = TmdbMediaSearchRepository(accessToken: 'test', client: client);

    final trendingItem = (await repository.trending(MediaType.tv)).single;
    final searchItem = (await repository.search('Series', MediaType.tv)).single;

    expect(trendingItem.releaseDate, DateTime(2020));
    expect(trendingItem.latestEpisodeAirDate, latestEpisodeAirDate);
    expect(trendingItem.latestEpisodeNumber, 2);
    expect(trendingItem.latestSeasonAirDate, latestEpisodeAirDate);
    expect(trendingItem.numberOfSeasons, 2);
    expect(trendingItem.releasedSeasonCount, 1);
    expect(searchItem.latestSeasonAirDate, latestEpisodeAirDate);
    expect(searchItem.releasedSeasonCount, 1);
    expect(detailRequests, 1);
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

  testWidgets('TV poster cards show new series and new season labels', (tester) async {
    final now = DateTime.now();
    final feed = HomeFeedController(
      repository: _Repository(
        (id, type) async => [],
        tvSeries: [
          MediaItem(id: 2, title: 'New Series', overview: '', releaseDate: now.subtract(const Duration(days: 7))),
          MediaItem(
            id: 3,
            title: 'New Season',
            overview: '',
            releaseDate: now.subtract(const Duration(days: 365)),
            latestEpisodeAirDate: now.subtract(const Duration(days: 7)),
            latestEpisodeNumber: 1,
            numberOfSeasons: 2,
            releasedSeasonCount: 2,
          ),
          MediaItem(
            id: 4,
            title: 'No New Season',
            overview: '',
            releaseDate: now.subtract(const Duration(days: 365)),
            latestEpisodeAirDate: now.subtract(const Duration(days: 31)),
            latestEpisodeNumber: 2,
          ),
          MediaItem(
            id: 9,
            title: 'New Single-Season Series',
            overview: '',
            releaseDate: now.subtract(const Duration(days: 365)),
            latestEpisodeAirDate: now.subtract(const Duration(days: 7)),
            latestEpisodeNumber: 2,
            numberOfSeasons: 1,
            releasedSeasonCount: 1,
          ),
          MediaItem(
            id: 8,
            title: 'New Season Episode Two',
            overview: '',
            releaseDate: now.subtract(const Duration(days: 365)),
            latestEpisodeAirDate: now.subtract(const Duration(days: 7)),
            latestEpisodeNumber: 2,
            numberOfSeasons: 2,
            releasedSeasonCount: 2,
          ),
        ],
      ),
    );
    final favorites = FavoritesController(repository: _EmptyFavorites());
    final history = WatchHistoryController(repository: _EmptyHistory());
    final search = MediaSearchController(repository: _Repository((id, type) async => []));
    addTearDown(feed.dispose);
    addTearDown(favorites.dispose);
    addTearDown(history.dispose);
    addTearDown(search.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowseHomeView(
            feedController: feed,
            favoritesController: favorites,
            historyController: history,
            searchController: search,
            onOpenDetails: (item, type) {},
            onPlay: (item, type) {},
            onResume: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Trending TV Series'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.text('NEW SERIES'), findsNWidgets(2));
    expect(find.text('SEASON PREMIERE'), findsOneWidget);
    expect(find.text('NEW SEASON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent movie posters and season premieres are labeled', (tester) async {
    final now = DateTime.now();
    final feed = HomeFeedController(
      repository: _Repository(
        (id, type) async => [],
        movies: [MediaItem(id: 5, title: 'New Movie', overview: '', releaseDate: now.subtract(const Duration(days: 7)))],
        tvSeries: const [],
      ),
    );
    final favorites = FavoritesController(repository: _EmptyFavorites());
    final history = WatchHistoryController(
      repository: _EmptyHistory(
        entries: [
          WatchHistoryEntry(
            item: MediaItem(
              id: _series.id,
              title: _series.title,
              overview: '',
              latestEpisodeAirDate: now.subtract(const Duration(days: 7)),
              latestEpisodeNumber: 1,
              latestSeasonAirDate: now.subtract(const Duration(days: 7)),
              numberOfSeasons: 2,
              releasedSeasonCount: 2,
            ),
            type: MediaType.tv,
            season: 2,
            episode: 1,
            watchedAt: now,
          ),
        ],
      ),
    );
    final search = MediaSearchController(repository: _Repository((id, type) async => []));
    addTearDown(feed.dispose);
    addTearDown(favorites.dispose);
    addTearDown(history.dispose);
    addTearDown(search.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowseHomeView(
            feedController: feed,
            favoritesController: favorites,
            historyController: history,
            searchController: search,
            onOpenDetails: (item, type) {},
            onPlay: (item, type) {},
            onResume: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SEASON PREMIERE'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Trending Movies'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.text('NEW MOVIE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final type in MediaType.values) {
    testWidgets('search result posters show recent ${type.name} tags', (tester) async {
      final now = DateTime.now();
      final movie = MediaItem(id: 6, title: 'Recent Movie', overview: '', releaseDate: now.subtract(const Duration(days: 7)));
      final series = MediaItem(
        id: 7,
        title: 'Recent Series Premiere',
        overview: '',
        releaseDate: now.subtract(const Duration(days: 365)),
        latestEpisodeAirDate: now.subtract(const Duration(days: 7)),
        latestEpisodeNumber: 2,
        latestSeasonAirDate: now.subtract(const Duration(days: 7)),
      );
      final repository = _Repository((id, mediaType) async => [], movieSearchResults: [movie], tvSearchResults: [series]);
      final feed = HomeFeedController(repository: repository);
      final favorites = FavoritesController(repository: _EmptyFavorites());
      final history = WatchHistoryController(repository: _EmptyHistory());
      final search = MediaSearchController(repository: repository);
      addTearDown(feed.dispose);
      addTearDown(favorites.dispose);
      addTearDown(history.dispose);
      addTearDown(search.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrowseHomeView(
              feedController: feed,
              favoritesController: favorites,
              historyController: history,
              searchController: search,
              initialQuery: 'recent',
              initialMediaType: type,
              onOpenDetails: (item, mediaType) {},
              onPlay: (item, mediaType) {},
              onResume: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(type == MediaType.movie ? 'NEW MOVIE' : 'SEASON PREMIERE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fromDeepLink in [false, true]) {
    testWidgets('search URL and browser back preserve search with deep link $fromDeepLink', (tester) async {
      const query = 'Series & friends + / ? #';
      final repository = _Repository((id, type) async => []);
      final feed = HomeFeedController(repository: repository);
      final favorites = FavoritesController(repository: _EmptyFavorites());
      final history = WatchHistoryController(repository: _EmptyHistory());
      final search = MediaSearchController(repository: repository);
      addTearDown(feed.dispose);
      addTearDown(favorites.dispose);
      addTearDown(history.dispose);
      addTearDown(search.dispose);
      final reflectsImperativeAPIs = GoRouter.optionURLReflectsImperativeAPIs;
      GoRouter.optionURLReflectsImperativeAPIs = true;
      addTearDown(() => GoRouter.optionURLReflectsImperativeAPIs = reflectsImperativeAPIs);
      await tester.pump();

      final router = GoRouter(
        initialLocation: fromDeepLink ? AppRoutes.homeSearch(query, type: MediaType.tv) : AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => Scaffold(
              body: BrowseHomeView(
                feedController: feed,
                favoritesController: favorites,
                historyController: history,
                searchController: search,
                initialQuery: (AppRoutes.parse(state.uri.toString()) as HomeRoute).query,
                initialMediaType: (AppRoutes.parse(state.uri.toString()) as HomeRoute).type,
                onOpenDetails: (item, type) => context.push(AppRoutes.details(type, item.id)),
                onPlay: (item, type) {},
                onResume: (_) {},
              ),
            ),
          ),
          GoRoute(
            path: '/details/:type/:id',
            builder: (context, state) => const Scaffold(body: Text('Selected details')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      if (fromDeepLink) {
        expect(search.query, query);
        expect(search.mediaType, MediaType.tv);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, query);
        expect(find.text('Series'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      }
      final input = tester.state<EditableTextState>(find.byType(EditableText));
      await tester.tap(find.byType(TextField));
      search.setMediaType(MediaType.movie);
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.queryParameters, {'q': query, 'type': 'movie'});
      search.setMediaType(MediaType.tv);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.queryParameters, {'q': query, 'type': 'tv'});
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(input));
      final results = search.state;
      final homeRouteInformation = router.routeInformationProvider.value;

      await tester.tap(find.text('Series').last);
      await tester.pumpAndSettle();
      expect(find.text('Selected details'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(search.query, query);
      expect(search.state, same(results));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.text('Series').last);
      await tester.pumpAndSettle();
      expect(find.text('Selected details'), findsOneWidget);
      await router.routeInformationProvider.didPushRouteInformation(homeRouteInformation);
      await tester.pumpAndSettle();

      expect(search.query, query);
      expect(search.mediaType, MediaType.tv);
      expect(search.state, same(results));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, query);
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(input));
      expect(find.text('Series'), findsWidgets);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(search.query, isEmpty);
      expect(router.routeInformationProvider.value.uri.toString(), AppRoutes.home);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.enterText(find.byType(TextField), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.queryParameters, {'q': query, 'type': 'tv'});

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(search.query, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(router.routeInformationProvider.value.uri.toString(), AppRoutes.home);
      expect(tester.takeException(), isNull);
    });
  }

  for (final enableDpadFocus in [false, true]) {
    testWidgets('opening search shows the keyboard with D-pad focus $enableDpadFocus', (tester) async {
      final repository = _Repository((id, type) async => []);
      final feed = HomeFeedController(repository: repository);
      final favorites = FavoritesController(repository: _EmptyFavorites());
      final history = WatchHistoryController(repository: _EmptyHistory());
      final search = MediaSearchController(repository: repository);
      addTearDown(feed.dispose);
      addTearDown(favorites.dispose);
      addTearDown(history.dispose);
      addTearDown(search.dispose);
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrowseHomeView(
              feedController: feed,
              favoritesController: favorites,
              historyController: history,
              searchController: search,
              enableDpadFocus: enableDpadFocus,
              onOpenDetails: (item, type) {},
              onPlay: (item, type) {},
              onResume: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialInput = tester.state<EditableTextState>(find.byType(EditableText));
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(initialInput));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      tester.testTextInput.hide();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(initialInput));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
      await tester.pump();
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
      await tester.scrollUntilVisible(find.text('Trending trailers'), 200, scrollable: find.byType(Scrollable).first);
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
