import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_country.dart';

void main() {
  test('country names use language codes and fall back to the supplied name', () {
    final country = LiveTvCountry.fromJson({
      'code': 'FR',
      'name': 'France',
      'flag': '🇫🇷',
      'names': {'en': 'France', 'es': 'Francia', 'ca': 'França'},
    });
    expect(country.localizedName(const Locale('es', 'ES')), 'Francia');
    expect(country.localizedName(const Locale('ca', 'ES')), 'França');
    expect(country.localizedName(const Locale('en')), 'France');
    expect(country.localizedName(const Locale('de')), 'France');
    final legacy = LiveTvCountry.fromJson({'code': 'FR', 'name': 'France', 'flag': '🇫🇷'});
    expect(legacy.localizedName(const Locale('es')), 'France');
  });
}
