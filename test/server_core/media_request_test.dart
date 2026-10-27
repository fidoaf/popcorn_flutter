import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  final providers = MediaProviderRegistry([const _TestProvider('vidsrcbuzz')]);

  test('defaults to the registered provider and movie fields', () {
    final media = MediaRequest.parse({'id': 'tt1375666'}, providers: providers);

    expect(media.providerId, 'vidsrcbuzz');
    expect(media.type, 'movie');
    expect(media.id, 'tt1375666');
    expect(media.lang, 'en');
    expect(media.sub, '1');
    expect(media.season, '0');
    expect(media.episode, '0');
  });

  test('normalizes language and parses TV season and episode', () {
    final media = MediaRequest.parse({
      'provider': 'vidsrcbuzz',
      'type': 'TV',
      'id': ' 1399 ',
      'season': '2',
      'episode': '3',
      'lang': ' FR ',
      'sub': '0',
    }, providers: providers);

    expect(media.providerId, 'vidsrcbuzz');
    expect(media.type, 'tv');
    expect(media.id, '1399');
    expect(media.lang, 'fr');
    expect(media.sub, '0');
    expect(media.season, '2');
    expect(media.episode, '3');
  });

  test('supports the legacy imdbId parameter when id is empty', () {
    final media = MediaRequest.parse({
      'id': '',
      'imdbId': 'tt12345',
    }, providers: providers);

    expect(media.id, 'tt12345');
  });

  test('rejects unsupported providers and invalid media parameters', () {
    expect(
      () => MediaRequest.parse({
        'provider': 'unknown',
        'id': '1',
      }, providers: providers),
      throwsA(isA<InvalidMediaRequest>()),
    );
    expect(
      () => MediaRequest.parse({
        'type': 'tv',
        'id': '1',
        'season': '0',
        'episode': '2',
      }, providers: providers),
      throwsA(isA<InvalidMediaRequest>()),
    );
    expect(
      () => MediaRequest.parse({
        'id': '1',
        'lang': 'english',
      }, providers: providers),
      throwsA(isA<InvalidMediaRequest>()),
    );
    expect(
      () => MediaRequest.parse({'id': '1', 'sub': '2'}, providers: providers),
      throwsA(isA<InvalidMediaRequest>()),
    );
  });
}

final class _TestProvider implements MediaProvider {
  const _TestProvider(this.id);

  @override
  final String id;

  @override
  String get label => id;
}
