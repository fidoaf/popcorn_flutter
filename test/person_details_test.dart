import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/infrastructure/tmdb_media_search_repository.dart';

void main() {
  test('person profile route is deep-linkable', () {
    expect(AppRoutes.person(1136406), '/person/1136406');
    expect(AppRoutes.parse('/person/1136406'), isA<PersonRoute>());
    expect(AppRoutes.parse('/person/not-an-id'), isA<UnknownRoute>());
  });

  test('person profile includes biography and popularity-sorted combined credits', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/3/person/1136406');
      expect(request.url.queryParameters, {'append_to_response': 'combined_credits'});
      return http.Response(
        jsonEncode({
          'id': 1136406,
          'name': 'Tom Holland',
          'biography': 'A biography.',
          'birthday': '1996-06-01',
          'place_of_birth': 'London, England',
          'known_for_department': 'Acting',
          'profile_path': '/profile.jpg',
          'combined_credits': {
            'cast': [
              {'id': 2, 'media_type': 'movie', 'title': 'Less popular', 'overview': '', 'popularity': 2, 'character': 'A'},
              {'id': 3, 'media_type': 'tv', 'name': 'More popular', 'overview': '', 'popularity': 5, 'character': 'B'},
              {'id': 4, 'media_type': 'person', 'name': 'Ignored', 'overview': '', 'popularity': 100},
            ],
            'crew': [
              {'id': 3, 'media_type': 'tv', 'name': 'More popular', 'overview': '', 'popularity': 4, 'job': 'Director'},
            ],
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    final repository = TmdbMediaSearchRepository(accessToken: 'test', client: client);

    final person = await repository.personDetails(1136406);

    expect(person.name, 'Tom Holland');
    expect(person.biography, 'A biography.');
    expect(person.birthday, DateTime(1996, 6, 1));
    expect(person.profileUrl, Uri.parse('https://image.tmdb.org/t/p/w185/profile.jpg'));
    expect(person.knownFor.map((credit) => credit.item.title), ['More popular', 'Less popular']);
    expect(person.knownFor.map((credit) => credit.type), [MediaType.tv, MediaType.movie]);
  });
}
