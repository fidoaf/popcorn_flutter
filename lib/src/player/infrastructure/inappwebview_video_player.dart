import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';

final class InappwebviewVideoPlayer extends VideoPlayer {
  const InappwebviewVideoPlayer({super.key, required super.source});

  @override
  Widget build(BuildContext context) {
    return InAppWebView(initialUrlRequest: URLRequest(url: WebUri.uri(source)));
  }
}
