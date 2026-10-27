import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('registry supports providers with different capabilities', () {
    final providers = MediaProviderRegistry([
      _EmbedOnlyProvider(),
      _StreamProvider(),
    ]);

    expect(providers.get('embed-only'), isA<EmbedPageProvider>());
    expect(providers.get('streaming'), isA<StreamExtractingProvider>());
    expect(providers.get('streaming'), isA<SourceListingProvider>());
    expect(providers.get('embed-only'), isNot(isA<StreamExtractingProvider>()));
  });

  test('source listings preserve provider metadata for scoped references', () {
    final listing = SourceListing(
      token: 'provider-token',
      sources: const [
        ProviderSource(
          ref: 'source-ref',
          name: 'Server A',
          language: 'en',
          flag: 'us',
        ),
      ],
    );

    expect(listing.sources.single.toReferenceData(token: listing.token), {
      'ref': 'source-ref',
      'token': 'provider-token',
    });
    expect(listing.sources.single.language, 'en');
    expect(listing.sources.single.flag, 'us');
  });
}

final class _EmbedOnlyProvider implements EmbedPageProvider {
  @override
  String get id => 'embed-only';

  @override
  String get label => 'Embed';

  @override
  Uri embedUrl(MediaRequest media) => Uri.https('example.test', '/${media.id}');
}

final class _StreamProvider
    implements StreamExtractingProvider, SourceListingProvider {
  @override
  String get id => 'streaming';

  @override
  String get label => 'Streaming';

  @override
  Future<ResolvedStream> extract(
    MediaRequest media, {
    SourceReference? selectedSource,
  }) async => ResolvedStream(
    uri: Uri.https('example.test', '/${media.id}.m3u8'),
    type: 'hls',
  );

  @override
  Future<SourceListing> listSources(MediaRequest media) async =>
      SourceListing(sources: const []);
}
