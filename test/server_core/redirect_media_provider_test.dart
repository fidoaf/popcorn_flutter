import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('expands TV path and query templates', () {
    final provider = RedirectMediaProvider(
      id: 'nxsha',
      label: 'Nxsha',
      host: 'web.nxsha.app',
      path: '/embed/{type}/{id}/{season}/{episode}',
      parameters: const {'lang': '{language}', 'sub': '{subtitles}'},
    );
    const media = MediaRequest(
      providerId: 'nxsha',
      type: 'tv',
      id: '1399',
      lang: 'fr-CA',
      sub: '0',
      season: '2',
      episode: '3',
    );

    expect(
      provider.embedUrl(media).toString(),
      'https://web.nxsha.app/embed/tv/1399/2/3?lang=fr-CA&sub=0',
    );
  });

  test('omits movie-only season and episode query parameters', () {
    final provider = RedirectMediaProvider(
      id: 'cinesrc',
      label: 'CineSrc',
      host: 'cinesrc.st',
      path: '/embed/{type}/{id}',
      parameters: const {'s': '{season}', 'e': '{episode}'},
    );
    const media = MediaRequest(
      providerId: 'cinesrc',
      type: 'movie',
      id: '12345',
      lang: 'en',
      sub: '1',
      season: '0',
      episode: '0',
    );

    expect(
      provider.embedUrl(media).toString(),
      'https://cinesrc.st/embed/movie/12345',
    );
  });

  test('encodes path substitutions and validates provider templates', () {
    final provider = RedirectMediaProvider(
      id: 'test',
      label: 'Test',
      host: 'example.test',
      path: '/embed/{id}',
    );
    const media = MediaRequest(
      providerId: 'test',
      type: 'movie',
      id: 'part/one',
      lang: 'en',
      sub: '1',
      season: '0',
      episode: '0',
    );

    expect(provider.embedUrl(media).path, '/embed/part%2Fone');
    expect(
      () => RedirectMediaProvider(
        id: 'test',
        label: 'Test',
        host: 'example.test',
        path: '/{unknown}',
      ).embedUrl(media),
      throwsFormatException,
    );
    expect(
      () => RedirectMediaProvider(
        id: 'test',
        label: 'Test',
        host: 'example.test',
        path: '//invalid',
      ),
      throwsArgumentError,
    );
  });
}
