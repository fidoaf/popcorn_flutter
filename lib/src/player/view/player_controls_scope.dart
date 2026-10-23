import 'dart:async';

import 'package:flutter/widgets.dart';

class PlayerControlsController extends ValueNotifier<bool> {
  PlayerControlsController() : super(true);

  Timer? _timer;
  bool _playing = false;

  set playing(bool playing) {
    if (_playing == playing) return;
    _playing = playing;
    show();
  }

  void show() {
    value = true;
    _timer?.cancel();
    if (_playing) {
      _timer = Timer(const Duration(seconds: 3), () => value = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Shares the native player's control visibility with its surrounding overlays.
class PlayerControlsScope extends StatefulWidget {
  const PlayerControlsScope({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  static PlayerControlsController? controllerOf(BuildContext context) => context.getInheritedWidgetOfExactType<_ControlsScope>()?.notifier;

  static bool visibleOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ControlsScope>()?.notifier?.value ?? true;

  @override
  State<PlayerControlsScope> createState() => _PlayerControlsScopeState();
}

class _PlayerControlsScopeState extends State<PlayerControlsScope> {
  final _controller = PlayerControlsController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.enabled
      ? widget.child
      : _ControlsScope(
          notifier: _controller,
          child: MouseRegion(
            hitTestBehavior: HitTestBehavior.opaque,
            onHover: (_) => _controller.show(),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _controller.show(),
              child: Focus(
                onKeyEvent: (_, _) {
                  _controller.show();
                  return KeyEventResult.ignored;
                },
                child: widget.child,
              ),
            ),
          ),
        );
}

class _ControlsScope extends InheritedNotifier<PlayerControlsController> {
  const _ControlsScope({required super.notifier, required super.child});
}

class PlayerOverlayControls extends StatelessWidget {
  const PlayerOverlayControls({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = PlayerControlsScope.visibleOf(context);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 200), child: child),
      ),
    );
  }
}
