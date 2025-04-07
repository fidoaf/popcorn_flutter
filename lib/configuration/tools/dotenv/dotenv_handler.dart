import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/configuration/core/model/application_configuration.dart';

class DotEnvHandler extends ApplicationConfiguration {
  // static const String? _path;

  static final DotEnvHandler _singleton = DotEnvHandler._internal();

  factory DotEnvHandler._() {
    return _singleton;
  }

  DotEnvHandler._internal();

  static Future<DotEnvHandler> getInstance() async {
    // Use optional and a default empty map in case there is no .env file or is empty
    await dotenv.load(isOptional: true);
    return DotEnvHandler._();
  }

  @override
  String getString(String key) {
    return dotenv.get(key, fallback: '');
  }

  @override
  int getInt(String key) {
    return dotenv.getInt(key);
  }
}
