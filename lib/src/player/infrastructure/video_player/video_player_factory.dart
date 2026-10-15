import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/player_server_session.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/platform_video_player_native.dart'
    if (dart.library.js_interop) 'package:popcorn_flutter/src/player/infrastructure/video_player/platform_video_player_web.dart'
    as platform;

abstract final class VideoPlayerFactory {
  const VideoPlayerFactory._();

  /// Builds the platform's [VideoPlayer]. [engine] selects the backend (WebView
  /// by default, or the native `media_kit` player); [alternates] are extra
  /// stream URLs the native player races against [source] for the fastest one.
  static VideoPlayer create({
    Key? key,
    required MediaSource source,
    ValueChanged<Uri>? onUrlChanged,
    VideoPlayerEngine engine = VideoPlayerEngine.webView,
    List<Uri> alternates = const <Uri>[],
  }) {
    if (source.url.path == '/player' && source.headers.keys.any((key) => key.toLowerCase() == 'authorization')) {
      return _AuthorizedVideoPlayer(key: key, source: source, onUrlChanged: onUrlChanged, engine: engine, alternates: alternates);
    }
    return platform.createPlatformVideoPlayer(key: key, source: source, onUrlChanged: onUrlChanged, engine: engine, alternates: alternates);
  }
}

final class _AuthorizedVideoPlayer extends VideoPlayer {
  const _AuthorizedVideoPlayer({super.key, required super.source, super.onUrlChanged, required this.engine, required this.alternates});

  final VideoPlayerEngine engine;
  final List<Uri> alternates;

  @override
  Widget build(BuildContext context) => _PlayerSession(player: this);
}

class _PlayerSession extends StatefulWidget {
  const _PlayerSession({required this.player});

  final _AuthorizedVideoPlayer player;

  @override
  State<_PlayerSession> createState() => _PlayerSessionState();
}

class _PlayerSessionState extends State<_PlayerSession> {
  late Future<MediaSource> _source;

  @override
  void initState() {
    super.initState();
    _source = createPlayerServerSession(widget.player.source);
  }

  @override
  void didUpdateWidget(_PlayerSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.source.url != widget.player.source.url ||
        !mapEquals(oldWidget.player.source.headers, widget.player.source.headers)) {
      _source = createPlayerServerSession(widget.player.source);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MediaSource>(
    future: _source,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
      final source = snapshot.data;
      if (source == null || snapshot.connectionState != ConnectionState.done) return const SizedBox.expand();
      return platform.createPlatformVideoPlayer(
        source: source,
        onUrlChanged: widget.player.onUrlChanged,
        engine: widget.player.engine,
        alternates: widget.player.alternates,
      );
    },
  );
}
