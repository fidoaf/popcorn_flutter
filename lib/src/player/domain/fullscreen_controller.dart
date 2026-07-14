/// Controls the application's fullscreen state independently of the platform.
///
/// Implementations delegate to the appropriate native or web mechanism, so
/// callers (e.g. the video player) never depend on platform-specific APIs.
abstract interface class FullscreenController {
  Future<void> setFullscreen(bool enabled);
}
