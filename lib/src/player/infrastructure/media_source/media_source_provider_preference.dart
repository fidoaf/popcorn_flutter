import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user-selected media source provider name.
abstract final class MediaSourceProviderPreference {
  static const String key = 'player.mediaSourceProvider';

  static Future<String?> selectedProviderName() async =>
      (await SharedPreferences.getInstance()).getString(key);

  static Future<void> setSelectedProviderName(String? name) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = name == null
        ? await preferences.remove(key)
        : await preferences.setString(key, name);
    if (!saved) {
      throw StateError('Unable to save the media source provider preference.');
    }
  }
}