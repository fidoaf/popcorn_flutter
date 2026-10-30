import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/profile/domain/home_section.dart';
import 'package:popcorn_flutter/src/profile/domain/profile.dart';

void main() {
  group('Profile home sections', () {
    test('missing saved sections remain unset', () {
      final profile = Profile.fromRow({'id': 'profile-1', 'account_id': 'account-1', 'display_name': 'Home'});

      expect(profile.homeSections, isNull);
    });

    test('saved section identifiers map to known sections', () {
      final profile = Profile.fromRow({
        'id': 'profile-1',
        'account_id': 'account-1',
        'display_name': 'Home',
        'home_sections': ['movies', 'live_radio', 'unknown'],
      });

      expect(profile.homeSections, [HomeSection.movies, HomeSection.liveRadio]);
    });
  });
}
