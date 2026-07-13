import 'dart:async';
import 'dart:developer';

import 'package:popcorn_flutter/application/android/app_configuration.dart';
import 'package:popcorn_flutter/application/material/material_app.dart';
import 'package:popcorn_flutter/navigation/android/navigation_controller.dart';
import 'package:popcorn_flutter/navigation/domain/navigation_controller.dart';

class AndroidApplication extends MaterialApplication {
  static AndroidApplication? _instance;
  static final Completer<bool> _isReady = Completer();
  static final AndroidNavigationController _navigationController = AndroidNavigationController();

  static Future<AndroidApplication> run({required AndroidApplicationConfiguration configuration}) async {
    log('***************** Android ******************');
    _instance ??= AndroidApplication._(configuration: configuration, navigationController: _navigationController)..initialize().then((success) => _isReady.complete(success));
    return _instance!;
  }

  AndroidApplication._({required super.configuration, required super.navigationController});

  @override
  Future<bool> get ready => _isReady.future;

  @override
  NavigationController get navigationController => _navigationController;
}
