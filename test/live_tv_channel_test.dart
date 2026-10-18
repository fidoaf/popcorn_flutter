import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_channel.dart';

void main() {
  LiveTvChannel channel({String? logo, String? format}) =>
      LiveTvChannel.fromJson({'id': 'France3.fr', 'name': 'France 3', 'url': 'https://example.com/live.m3u8', 'logo': logo, 'logoFormat': format});

  test('recognizes SVG logos from data format or URL path', () {
    expect(channel(logo: 'https://example.com/logo', format: 'SVG').hasSvgLogo, isTrue);
    expect(channel(logo: 'https://example.com/logo.SVG?version=1').hasSvgLogo, isTrue);
    expect(channel(logo: 'https://example.com/logo.png', format: 'PNG').hasSvgLogo, isFalse);
  });

  test('retains logo URLs and rejects unsupported schemes', () {
    expect(channel(logo: 'https://example.com/logo.svg').logoUrl, Uri.parse('https://example.com/logo.svg'));
    expect(channel(logo: 'file:///private/logo.svg').logoUrl, isNull);
    expect(channel().logoUrl, isNull);
  });
}
