import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/infrastructure/platform_fullscreen_controller.dart';

/// Builds the [FullscreenController] implementation used by the app.
abstract final class FullscreenControllerFactory {
  const FullscreenControllerFactory._();

  static FullscreenController create() => const PlatformFullscreenController();
}
