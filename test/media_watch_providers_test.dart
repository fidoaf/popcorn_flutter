import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_watch_provider.dart';
import 'package:popcorn_flutter/src/search/infrastructure/tmdb_media_search_repository.dart';

void main() {
  test('loads regional providers across availability types and deduplicates logos', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/3/movie/42/watch/providers');
      return http.Response(
        jsonEncode({
          'results': {
            'ES': {
              'link': 'https://www.justwatch.com/es/pelicula/title',
              'flatrate': [
                {'provider_id': 8, 'provider_name': 'Netflix', 'logo_path': '/netflix.png'},
              ],
              'free': [
                {'provider_id': 8, 'provider_name': 'Netflix', 'logo_path': '/netflix.png'},
              ],
              'ads': [
                {'provider_id': 20, 'provider_name': 'Provider with ads', 'logo_path': '/ads.png'},
              ],
              'rent': [
                {'provider_id': 30, 'provider_name': 'Rental provider', 'logo_path': '/rent.png'},
              ],
              'buy': [
                {'provider_id': 40, 'provider_name': 'Purchase provider', 'logo_path': '/buy.png'},
              ],
            },
            'US': {
              'flatrate': [
                {'provider_id': 99, 'provider_name': 'Other region', 'logo_path': '/other.png'},
              ],
            },
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    final repository = TmdbMediaSearchRepository(accessToken: 'test', client: client);

    final providers = await repository.watchProviders(42, MediaType.movie, region: 'es');

    expect(providers.map((provider) => provider.id), [8, 20, 30, 40]);
    expect(providers.first.name, 'Netflix');
    expect(providers.first.logoUrl, Uri.parse('https://image.tmdb.org/t/p/w92/netflix.png'));
    expect(providers.first.justWatchUrl, Uri.parse('https://www.justwatch.com/es/pelicula/title'));
  });

  test('uses the matching provider-specific JustWatch clickout', () async {
    const clickoutUrl = 'https://click.justwatch.com/a?cx=offer-context&r=https%3A%2F%2Fapp.primevideo.com%2Fdetail%3Fgti%3Dtest';
    final client = MockClient((request) async {
      if (request.url.host == 'player.example') {
        expect(request.headers['Authorization'], 'Bearer player-token');
        expect(request.url.path, '/watch-providers');
        expect(request.url.queryParameters, {'type': 'movie', 'title': 'Spider-Man: Brand New Day', 'year': '2026', 'region': 'ES'});
        return http.Response(jsonEncode({'10': clickoutUrl}), 200);
      }
      expect(request.headers['Authorization'], 'Bearer test');
      return http.Response(
        jsonEncode({
          'results': {
            'ES': {
              'link': 'https://www.themoviedb.org/movie/969681/watch?locale=ES',
              'rent': [
                {'provider_id': 10, 'provider_name': 'Amazon Video', 'logo_path': '/prime.png'},
              ],
            },
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    final repository = TmdbMediaSearchRepository(accessToken: 'test', playerServerUrl: Uri.parse('https://player.example'), playerServerToken: 'player-token', client: client);

    final providers = await repository.watchProviders(969681, MediaType.movie, region: 'ES', title: 'Spider-Man: Brand New Day', year: 2026);

    expect(providers.single.id, 10);
    expect(providers.single.justWatchUrl, Uri.parse(clickoutUrl));
  });

  testWidgets('provider logos launch JustWatch clickouts on a phone-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedMethods = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcherChannel, (call) async {
      launchedMethods.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcherChannel, null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchProvidersBuilder(
            providers: Future.value([
              MediaWatchProvider(
                id: 8,
                name: 'Netflix',
                logoUrl: Uri.parse('https://image.tmdb.org/t/p/w92/netflix.png'),
                justWatchUrl: Uri.parse('https://click.justwatch.com/a?cx=offer-context&r=https%3A%2F%2Fapp.primevideo.com%2Fdetail%3Fgti%3Dtest'),
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    expect(find.bySemanticsLabel('Netflix on JustWatch'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Netflix on JustWatch'));
    await tester.pump();

    expect(launchedMethods.single.arguments['url'], 'https://click.justwatch.com/a?cx=offer-context&r=https%3A%2F%2Fapp.primevideo.com%2Fdetail%3Fgti%3Dtest');
  });

  testWidgets('provider logos build under FluentApp without a Material ancestor', (tester) async {
    await tester.pumpWidget(
      fluent.FluentApp(
        home: fluent.ScaffoldPage(
          content: WatchProvidersBuilder(
            providers: Future.value([
              MediaWatchProvider(
                id: 8,
                name: 'Netflix',
                logoUrl: Uri.parse('https://image.tmdb.org/t/p/w92/netflix.png'),
                justWatchUrl: Uri.parse('https://www.justwatch.com'),
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
