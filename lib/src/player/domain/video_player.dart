import 'package:flutter/widgets.dart';

abstract class VideoPlayer extends StatelessWidget {
  const VideoPlayer({super.key, required this.source});

  final Uri source;
}
