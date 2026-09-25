import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';

/// Selects which playback backend renders a [VideoPlayer].
enum VideoPlayerEngine {
  /// The WebView/iframe player that hosts embedded provider players.
  webView,

  /// The native `media_kit` player that plays streams directly.
  mediaKit,
}

abstract class VideoPlayer extends StatelessWidget {
  const VideoPlayer({super.key, required this.source, this.onUrlChanged});

  final MediaSource source;

  /// Called whenever the player navigates to a new URL (e.g. the embedded
  /// player advancing to the next episode). `null` disables the notification.
  final ValueChanged<Uri>? onUrlChanged;
}
