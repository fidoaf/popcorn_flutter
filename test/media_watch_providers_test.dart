import 'dart:convert';

import 'package:flutter/material.dart';
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
  });

  testWidgets('provider logos render without visible provider names', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchProvidersBuilder(
            providers: Future.value([MediaWatchProvider(id: 8, name: 'Netflix', logoUrl: Uri.parse('https://image.tmdb.org/t/p/w92/netflix.png'))]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
  });
}
