import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

final class MediaRegionPreference {
  MediaRegionPreference._();

  static const _key = 'media_region';

  static String get deviceRegion => (PlatformDispatcher.instance.locale.countryCode ?? 'US').toUpperCase();

  static Future<String> currentRegion() async => await savedRegion() ?? deviceRegion;

  static Future<String?> savedRegion() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key)?.toUpperCase();
    return saved != null && RegExp(r'^[A-Z]{2}$').hasMatch(saved) ? saved : null;
  }

  static Future<void> setRegion(String? region) async {
    final preferences = await SharedPreferences.getInstance();
    if (region == null) {
      await preferences.remove(_key);
      return;
    }
    final normalized = region.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
      throw ArgumentError.value(region, 'region', 'Expected an ISO 3166-1 alpha-2 country code');
    }
    await preferences.setString(_key, normalized);
  }
}
