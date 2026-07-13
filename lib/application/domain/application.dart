import 'package:meta/meta.dart';
import 'package:popcorn_flutter/application/domain/application_configuration.dart';
import 'package:popcorn_flutter/navigation/domain/navigation_controller.dart';

abstract class Application {
  final ApplicationConfiguration configuration;
  Application({required this.configuration});

  NavigationController get navigationController;

  Future<bool> get ready;

  @protected
  Future<bool> initialize();

  @nonVirtual
  Future<void> showNotFoundPage() async {
    navigationController.showNotFoundPage();
  }

  @nonVirtual
  Future<void> goToMainPage() async {
    navigationController.goToMainPage();
  }
}
