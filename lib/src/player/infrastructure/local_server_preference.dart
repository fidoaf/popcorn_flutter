import 'package:shared_preferences/shared_preferences.dart';

abstract final class LocalServerPreference {
  static const key = 'player.localServer';
  static const _legacyKey = 'windows.localPlayerServer';

  static Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key) ?? preferences.getBool(_legacyKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(key, enabled)) {
      throw StateError('Unable to save the local server preference.');
    }
    if (preferences.containsKey(_legacyKey)) {
      await preferences.remove(_legacyKey);
    }
  }
}
