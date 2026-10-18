import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/home/view/browse_home_view.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_controller.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';

class _Repository implements MediaSearchRepository {
  @override
  Future<List<MediaItem>> trending(MediaType type) async => [];
  @override
  Future<List<MediaItem>> search(String query, MediaType type) async => [const MediaItem(id: 1, title: 'Movie result', overview: '')];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Favorites implements FavoritesRepository {
  @override
  Future<List<FavoriteMedia>> load() async => [];
  @override
  Future<void> save(List<FavoriteMedia> favorites) async {}
}

void main() {
  testWidgets('Live TV search chip debounces queries, renders channel actions and switches back to movies', (tester) async {
    final requests = <Uri>[];
    final live = LiveTvController(
      serverToken: '',
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode({
            'channels': request.url.queryParameters['q'] == 'missing'
                ? []
                : [
                    {'id': 'News.fr', 'name': 'News channel', 'url': 'https://example.com/live.m3u8'},
                  ],
          }),
          200,
        );
      }),
    );
    final search = MediaSearchController(repository: _Repository());
    final favorites = FavoritesController(repository: _Favorites());
    addTearDown(live.dispose);
    addTearDown(search.dispose);
    addTearDown(favorites.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: HomeSearchOverlay(
              active: true,
              onActivate: () {},
              controller: search,
              favoritesController: favorites,
              onClose: () {},
              onOpenDetails: (_) {},
              onPlay: (_) {},
              liveTvController: live,
            ),
          ),
        ),
        GoRoute(
          path: '/live-tv/:id',
          builder: (context, state) => const Scaffold(body: Text('Channel details')),
        ),
        GoRoute(
          path: '/live-tv/:id/watch',
          builder: (context, state) => const Scaffold(body: Text('Channel watch')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live TV'));
    await tester.pumpAndSettle();
    expect(find.text('News channel'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'news');
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, hasLength(1));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(requests.last.queryParameters['q'], 'news');
    expect(requests.last.queryParameters.containsKey('country'), isFalse);
    await tester.tap(find.text('News channel'));
    await tester.pumpAndSettle();
    expect(find.text('Channel details'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    await tester.pumpAndSettle();
    expect(find.text('Channel watch'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('News channel'), findsNothing);
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(search.query, 'missing');
    expect(find.text('Movie result'), findsOneWidget);
  });
}
