import 'package:popcorn_flutter/configuration/core/model/application_configuration.dart';
import 'package:popcorn_flutter/configuration/tools/dotenv/dotenv_handler.dart';
import 'package:popcorn_flutter/storage/core/model/application_storage.dart';
import 'package:popcorn_flutter/storage/tools/preference_handler.dart';
import 'package:popcorn_flutter/window/core/model/window_handler.dart';
import 'package:popcorn_flutter/window/tools/window_manager/window_manager.dart';

class ServiceLocator {
  ServiceLocator._();

  static final _cache = <Type, dynamic>{};

  static init() async {
    put<ApplicationConfiguration>(await DotEnvHandler.getInstance());
    put<ApplicationStorage>(await PreferenceHandler.getInstance());
    put<WindowHandler>(await WindowManager.getInstance());
  }

  static void put<T>(T obj) {
    _cache[T] = obj;
  }

  static T get<T>() {
    return _cache[T];
  }

  static ApplicationConfiguration get configuration => get<ApplicationConfiguration>();
  static ApplicationStorage get storage => get<ApplicationStorage>();
  static WindowHandler get window => get<WindowHandler>();
}
