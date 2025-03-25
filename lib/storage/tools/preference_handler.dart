import 'package:popcorn_flutter/storage/core/model/application_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceHandler extends ApplicationStorage {
  static final PreferenceHandler _singleton = PreferenceHandler._internal();

  factory PreferenceHandler._() {
    return _singleton;
  }

  PreferenceHandler._internal();

  static late final SharedPreferences _prefs;

  static Future<PreferenceHandler> getInstance() async {
    _prefs = await SharedPreferences.getInstance();
    return PreferenceHandler._();
  }

  @override
  String? getString(String key) {
    return _prefs.getString(key);
  }

  @override
  int? getInt(String key) {
    return _prefs.getInt(key);
  }
  
  @override
  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }
  
  @override
  Future<bool> setStringList(String key, List<String> value) {
    return _prefs.setStringList(key, value);
  }
  
  @override
  Future<bool> clear() {
    return _prefs.clear();
  }
}
