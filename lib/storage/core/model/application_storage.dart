abstract class ApplicationStorage {
  String? getString(String key);

  int? getInt(String key);

  List<String>? getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);

  Future<bool> clear();
}
