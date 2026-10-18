import 'dart:ui';

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

  test('parses reported geoblocking without assuming missing metadata means blocked', () {
    for (final value in [true, false, null, 'true']) {
      final result = LiveTvChannel.fromJson({
        'id': 'Example.us',
        'name': 'Example TV',
        'url': 'https://example.com/live.m3u8',
        if (value != null) 'isGeoBlocked': value,
      });
      expect(result.isGeoBlocked, value == true);
    }
    expect(LiveTvChannel(id: 'example', name: 'Example', streamUrl: Uri.https('example.com', '/live')).isGeoBlocked, isFalse);
  });

  test('parses and localizes broadcast areas independently of geoblocking', () {
    final result = LiveTvChannel.fromJson({
      'id': 'Example.fr',
      'name': 'Example TV',
      'url': 'https://example.com/live.m3u8',
      'broadcastAreas': [
        {
          'code': 'c/FR',
          'name': 'France',
          'names': {'es': 'Francia', 'ca': 'França'},
        },
        {'code': 'ct/FRPAR', 'name': 'Paris'},
      ],
    });
    expect(result.broadcastAreas.first.localizedName(const Locale('es')), 'Francia');
    expect(result.broadcastAreas.first.localizedName(const Locale('ca', 'ES')), 'França');
    expect(result.broadcastAreas.first.localizedName(const Locale('en')), 'France');
    expect(result.broadcastAreas.last.localizedName(const Locale('es')), 'Paris');
    expect(result.isGeoBlocked, isFalse);
    expect(channel().broadcastAreas, isEmpty);
  });

  test('localizes the channel country and supports older catalogue responses', () {
    final result = LiveTvChannel.fromJson({
      'id': 'Example.fr',
      'name': 'Example TV',
      'url': 'https://example.com/live.m3u8',
      'country': 'FR',
      'countryNames': {'en': 'France', 'es': 'Francia', 'ca': 'França'},
    });
    expect(result.localizedCountry(const Locale('es')), 'Francia');
    expect(result.localizedCountry(const Locale('ca', 'ES')), 'França');
    expect(result.localizedCountry(const Locale('de')), 'FR');
    expect(LiveTvChannel(id: 'old', name: 'Old', streamUrl: result.streamUrl, country: 'CR').localizedCountry(const Locale('es')), 'CR');
  });

  test('rejects malformed broadcast area metadata', () {
    for (final areas in [
      'c/FR',
      [null],
      [
        {'code': 'c/FR'},
      ],
      [
        {
          'code': 'c/FR',
          'name': 'France',
          'names': {'es': 123},
        },
      ],
    ]) {
      expect(
        () => LiveTvChannel.fromJson({'id': 'Example.fr', 'name': 'Example TV', 'url': 'https://example.com/live.m3u8', 'broadcastAreas': areas}),
        throwsFormatException,
      );
    }
  });
}
