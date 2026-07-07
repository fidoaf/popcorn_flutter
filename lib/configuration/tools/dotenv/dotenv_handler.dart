
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
    await _loadDotEnv();
    return DotEnvHandler._();
  }

  static Future<void> _loadDotEnv() async {
    const fileName = '.env';

    // First try the current working directory.
    final localFile = File(fileName);
    if (await localFile.exists()) {
      await dotenv.load(fileName: fileName, isOptional: true);
      return;
    }

    final envFile = await _findEnvFileUpwards(Directory.current);
    if (envFile != null) {
      await dotenv.load(fileName: envFile.path, isOptional: true);
      return;
    }

    // Fallback to default loading behavior (assets or current directory).
    await dotenv.load(isOptional: true);
  }

  static Future<File?> _findEnvFileUpwards(Directory start) async {
    var dir = start;
    while (true) {
      final candidate = File('${dir.path}${Platform.pathSeparator}.env');
      if (await candidate.exists()) {
        return candidate;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        return null;
      }
      dir = parent;
    }
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
