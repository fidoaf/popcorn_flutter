import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('expiring references are available until their TTL elapses', () {
    var now = DateTime.utc(2026);
    final store = ExpiringReferenceStore<String>(
      ttl: const Duration(seconds: 10),
      clock: () => now,
      idGenerator: () => 'reference',
    );

    final id = store.add('value');
    now = now.add(const Duration(seconds: 9));
    expect(store.get(id), 'value');
    now = now.add(const Duration(seconds: 1));
    expect(store.get(id), isNull);
  });

  test('subtitle references retain their provider and expire', () {
    var now = DateTime.utc(2026);
    final store = SubtitleRefStore(
      clock: () => now,
      idGenerator: () => 'subtitle',
    );

    final id = store.add('provider-subtitle-ref', 'vidsrcbuzz');
    expect(
      store.get(id),
      isA<SubtitleReference>()
          .having((entry) => entry.ref, 'ref', 'provider-subtitle-ref')
          .having((entry) => entry.providerId, 'providerId', 'vidsrcbuzz'),
    );
    now = now.add(const Duration(minutes: 5));
    expect(store.get(id), isNull);
  });

  test('source references are scoped to provider and media identity', () {
    const media = MediaRequest(
      providerId: 'vidsrcbuzz',
      type: 'tv',
      id: '1399',
      lang: 'fr',
      sub: '0',
      season: '2',
      episode: '3',
    );
    const otherEpisode = MediaRequest(
      providerId: 'vidsrcbuzz',
      type: 'tv',
      id: '1399',
      lang: 'fr',
      sub: '0',
      season: '2',
      episode: '4',
    );
    final store = SourceRefStore(idGenerator: () => 'source');
    final id = store.add(
      {'ref': 'source-ref', 'token': 'opaque-token'},
      'vidsrcbuzz',
      media,
    );

    expect(store.get(id, 'vidsrcbuzz', media)?.source, {
      'ref': 'source-ref',
      'token': 'opaque-token',
    });
    expect(store.get(id, 'other-provider', media), isNull);
    expect(store.get(id, 'vidsrcbuzz', otherEpisode), isNull);
  });
}
