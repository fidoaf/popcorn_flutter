import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/fullscreen_controller_factory.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/media_kit_video_player.dart';
import 'package:web/web.dart' as web;

/// Web playback renders the source in a plain `<iframe>` by default, or uses the
/// native `media_kit` player when [engine] selects it.
///
/// `flutter_inappwebview_web` always stamps a `sandbox` attribute on its iframe
/// (and, in this version, offers no way to remove it), which some providers
/// reject ("Sandbox is not allowed"). Embedding directly lets us control — and
/// by default omit — the sandbox.
VideoPlayer createPlatformVideoPlayer({
  Key? key,
  required MediaSource source,
  ValueChanged<Uri>? onUrlChanged,
  VideoPlayerEngine engine = VideoPlayerEngine.webView,
  List<Uri> alternates = const <Uri>[],
}) => switch (engine) {
  VideoPlayerEngine.mediaKit => MediaKitVideoPlayer(
    key: key,
    source: source,
    fullscreenController: FullscreenControllerFactory.create(),
    alternates: alternates,
    onUrlChanged: onUrlChanged,
  ),
  VideoPlayerEngine.webView => WebVideoPlayer(key: key, source: source, onUrlChanged: onUrlChanged),
};

/// A [VideoPlayer] that embeds the source in a raw `<iframe>` platform view.
final class WebVideoPlayer extends VideoPlayer {
  WebVideoPlayer({super.key, required super.source, super.onUrlChanged}) : _viewType = 'popcorn-iframe-${source.url}?sandbox=${source.sandbox}' {
    _registerViewFactory(_viewType, source);
  }

  final String _viewType;

  /// View types already registered this session; registration is process-wide
  /// and must happen at most once per type.
  static final Set<String> _registered = <String>{};

  /// The `sandbox` tokens applied when a source opts into sandboxed playback
  /// (`sandbox: true`); enough for the embedded player to run while still
  /// blocking top-level navigation and downloads.
  static const _sandboxTokens = 'allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation';

  static void _registerViewFactory(String viewType, MediaSource source) {
    if (!_registered.add(viewType)) return;
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..allow = 'fullscreen; autoplay; encrypted-media; picture-in-picture'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      iframe.style
        ..border = 'none'
        ..height = '100%'
        ..width = '100%';
      // Only sandbox when the source explicitly opts in; the attribute is
      // omitted otherwise so providers that refuse sandboxed frames can play.
      if (source.sandbox == true) iframe.setAttribute('sandbox', _sandboxTokens);
      // Prefer inline HTML (e.g. a self-contained YouTube host) when provided.
      if (source.data != null) {
        iframe.srcdoc = source.data!.toJS;
      } else {
        iframe.src = source.url.toString();
      }
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
