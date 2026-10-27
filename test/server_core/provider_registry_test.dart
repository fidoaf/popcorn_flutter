import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test(
    'selects the configured default or falls back to the first provider',
    () {
      final providers = MediaProviderRegistry([
        const _TestProvider('first', 'First'),
        const _TestProvider('vidsrcbuzz', 'VidSrc'),
      ]);
      final fallback = MediaProviderRegistry([
        const _TestProvider('first', 'First'),
        const _TestProvider('second', 'Second'),
      ], defaultProviderId: 'missing');

      expect(providers.defaultProviderId, 'vidsrcbuzz');
      expect(fallback.defaultProviderId, 'first');
      expect(
        MediaProviderRegistry([]).defaultProviderId,
        defaultMediaProviderId,
      );
    },
  );

  test('lists the default first and resolves registered providers', () {
    final providers = MediaProviderRegistry([
      const _TestProvider('first', 'First'),
      const _TestProvider('second', 'Second'),
    ], defaultProviderId: 'second');

    expect(providers.list().map((provider) => provider.id), [
      'second',
      'first',
    ]);
    expect(providers.get('first').label, 'First');
    expect(providers.contains('missing'), isFalse);
    expect(
      () => providers.get('missing'),
      throwsA(
        isA<UnsupportedMediaProvider>().having(
          (error) => error.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
  });

  test('later duplicate registrations replace the implementation', () {
    final providers = MediaProviderRegistry([
      const _TestProvider('same', 'Old'),
      const _TestProvider('same', 'New'),
    ]);

    expect(providers.list().map((provider) => [provider.id, provider.label]), [
      ['same', 'New'],
    ]);
  });
}

final class _TestProvider implements MediaProvider {
  const _TestProvider(this.id, this.label);

  @override
  final String id;

  @override
  final String label;
}
