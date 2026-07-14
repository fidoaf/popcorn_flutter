import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';

/// [FullscreenController] backed by the `fullscreen_window` plugin, which
/// resolves to the correct implementation for each platform (Android, iOS,
/// web, Windows, Linux) via a method channel.
final class PlatformFullscreenController implements FullscreenController {
  const PlatformFullscreenController();

  @override
  Future<void> setFullscreen(bool enabled) => FullScreenWindow.setFullScreen(enabled);
}
