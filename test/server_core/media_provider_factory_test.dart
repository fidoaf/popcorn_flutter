import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('builds HTTP providers and redirect providers from config', () {
    final factoryClient = _FakeHttpClient();
    final providers = CoreMediaProviderFactory.fromJson(
      config: {
        'initialProvider': 'Render',
        'providers': [
          _definition('Render', 'popcorn-flutter.onrender.com', '/player'),
          _definition('Vidsrc.buzz', 'vidsrc.buzz', '/embed/{type}/{id}'),
          _definition('OnlyPelis', 'onlypelis.com', '/pelicula/{id}/'),
          _definition('Custom', 'example.test', '/embed/{id}'),
        ],
      },
      httpClient: factoryClient,
      postClient: factoryClient,
    );

    expect(providers.defaultProviderId, 'vidsrcbuzz');
    expect(providers.list().map((provider) => provider.id), ['vidsrcbuzz', 'onlypelis', 'custom']);
    expect(providers.get('vidsrcbuzz'), isA<VidSrcBuzzProvider>());
    expect(providers.get('onlypelis'), isA<OnlyPelisProvider>());
    expect(providers.get('custom'), isA<RedirectMediaProvider>());
  });

  test('uses custom provider overrides and falls back to first configured provider', () {
    final factoryClient = _FakeHttpClient();
    final providers = CoreMediaProviderFactory.fromJson(
      config: {
        'initialProvider': 'unavailable',
        'providers': [_definition('Browser backend', 'browser.example.test', '/embed/{id}'), _definition('Another backend', 'another.example.test', '/{id}')],
      },
      httpClient: factoryClient,
      postClient: factoryClient,
      overrides: {'browserbackend': (definition) => _TestProvider(definition.id, definition.name)},
    );

    expect(providers.defaultProviderId, 'browserbackend');
    expect(providers.get('browserbackend'), isA<_TestProvider>());
  });

  test('builds Nxsha with the optional same-origin browser fetch adapter', () {
    final factoryClient = _FakeHttpClient();
    final browserClient = _FakeBrowserFetchClient();
    final providers = CoreMediaProviderFactory.fromJson(
      config: {
        'providers': [_definition('Nxsha', 'web.nxsha.app', '/embed/{type}/{id}')],
      },
      httpClient: factoryClient,
      postClient: factoryClient,
      sameOriginBrowserFetchClient: browserClient,
    );

    expect(providers.get('nxsha'), isA<NxshaProvider>());
    expect((providers.get('nxsha') as NxshaProvider).browserFetchClient, same(browserClient));
  });

  test('rejects duplicate and invalid provider definitions', () {
    final factoryClient = _FakeHttpClient();
    expect(
      () => CoreMediaProviderFactory.fromJson(
        config: {
          'providers': [_definition('Vidsrc.buzz', 'one.test', '/{id}'), _definition('Vidsrc buzz', 'two.test', '/{id}')],
        },
        httpClient: factoryClient,
        postClient: factoryClient,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CoreMediaProviderFactory.fromJson(config: {'providers': 'not-a-list'}, httpClient: factoryClient, postClient: factoryClient),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, Object?> _definition(String name, String host, String path) => {
  'name': name,
  'host': host,
  'scheme': 'https',
  'path': path,
  'parameters': const {'lang': '{language}'},
};

final class _FakeHttpClient implements ProviderHttpClient, ProviderHttpPostClient {
  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async =>
      ProviderHttpResponse(statusCode: 200, body: '');

  @override
  Future<ProviderHttpResponse> post(Uri uri, {required Map<String, String> headers, required String body, required Duration timeout}) async =>
      ProviderHttpResponse(statusCode: 200, body: '{}');
}

final class _FakeBrowserFetchClient implements SameOriginBrowserFetchClient {
  @override
  Future<ProviderHttpResponse> fetch(Uri uri, {required Map<String, String> headers, required Duration timeout}) async =>
      ProviderHttpResponse(statusCode: 200, body: '{}');
}

final class _TestProvider implements MediaProvider {
  const _TestProvider(this.id, this.label);

  @override
  final String id;

  @override
  final String label;
}
