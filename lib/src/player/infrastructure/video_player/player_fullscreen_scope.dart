import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';

/// Keeps fullscreen requests within the lifetime of a player.
final class PlayerFullscreenScope extends StatefulWidget {
  const PlayerFullscreenScope({super.key, required this.controller, required this.builder});

  final FullscreenController controller;
  final Widget Function(BuildContext context, FullscreenController controller) builder;

  @override
  State<PlayerFullscreenScope> createState() => _PlayerFullscreenScopeState();
}

class _PlayerFullscreenScopeState extends State<PlayerFullscreenScope> implements FullscreenController {
  Future<void> _pending = Future<void>.value();
  bool _closed = false;
  bool _mayBeFullscreen = false;

  @override
  Future<void> setFullscreen(bool enabled) {
    // Platform callbacks can still arrive while the player is being torn down.
    if (_closed) return Future<void>.value();
    final controller = widget.controller;
    final request = _pending.then<void>((_) async {
      if (enabled) _mayBeFullscreen = true;
      await controller.setFullscreen(enabled);
      _mayBeFullscreen = enabled;
    });
    _pending = request.then<void>((_) {}, onError: _logError);
    return request;
  }

  static void _logError(Object error, StackTrace stack) {
    debugPrint('[VideoPlayer] Could not change fullscreen state: $error\n$stack');
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, this);

  @override
  void dispose() {
    _closed = true;
    // Wait for an in-flight entry before exiting, otherwise it can re-enter
    // fullscreen after the details page has already been restored.
    final controller = widget.controller;
    unawaited(
      _pending
          .then<void>((_) async {
            if (_mayBeFullscreen) await controller.setFullscreen(false);
          })
          .catchError(_logError),
    );
    super.dispose();
  }
}
