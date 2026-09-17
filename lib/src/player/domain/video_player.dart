import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';

abstract class VideoPlayer extends StatelessWidget {
  const VideoPlayer({super.key, required this.source, this.onUrlChanged});

  final MediaSource source;

  /// Called whenever the player navigates to a new URL (e.g. the embedded
  /// player advancing to the next episode). `null` disables the notification.
  final ValueChanged<Uri>? onUrlChanged;
}
