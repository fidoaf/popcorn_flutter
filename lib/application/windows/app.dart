import 'dart:async';
import 'dart:developer';

import 'package:popcorn_flutter/application/material/material_app.dart';
import 'package:popcorn_flutter/application/windows/app_configuration.dart';
import 'package:popcorn_flutter/navigation/domain/navigation_controller.dart';
import 'package:popcorn_flutter/navigation/windows/navigation_controller.dart';

class WindowsApplication extends MaterialApplication {
  static WindowsApplication? _instance;
  static final Completer<bool> _isReady = Completer();
  static final WindowsNavigationController _navigationController = WindowsNavigationController();

  static Future<WindowsApplication> run({required WindowsApplicationConfiguration configuration}) async {
    log('***************** Windows ******************');
    _instance ??= WindowsApplication._(configuration: configuration, navigationController: _navigationController)..initialize().then((success) => _isReady.complete(success));
    return _instance!;
  }

  WindowsApplication._({required super.configuration, required super.navigationController});

  @override
  Future<bool> get ready => _isReady.future;

  @override
  NavigationController get navigationController => _navigationController;
}
