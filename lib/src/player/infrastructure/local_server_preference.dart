import 'package:shared_preferences/shared_preferences.dart';

abstract final class LocalServerPreference {
  static const key = 'windows.localPlayerServer';

  static Future<bool> isEnabled() async => (await SharedPreferences.getInstance()).getBool(key) ?? false;

  static Future<void> setEnabled(bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(key, enabled)) {
      throw StateError('Unable to save the local server preference.');
    }
  }
}
