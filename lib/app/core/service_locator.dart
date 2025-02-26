import 'package:shared_preferences/shared_preferences.dart';

class ServiceLocator {
  static final _cache = <Type, dynamic>{};

  static init() async {
    put<SharedPreferences>(await SharedPreferences.getInstance());
  }

  static void put<T>(T obj) {
    _cache[T] = obj;
  }

  static T get<T>() {
    return _cache[T];
  }
}
