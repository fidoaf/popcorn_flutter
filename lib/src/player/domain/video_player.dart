import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';

abstract class VideoPlayer extends StatelessWidget {
  const VideoPlayer({super.key, required this.source});

  final MediaSource source;
}
