import 'package:flutter/widgets.dart';

/// Shows a lightweight, self-dismissing toast using the app's [Overlay].
///
/// Works under a bare [WidgetsApp] (no [ScaffoldMessenger] required), so it is
/// safe to call from any toolkit (Material, Cupertino, Fluent, macOS) and on
/// web. Returns without doing anything when no [Overlay] is reachable.
void showAppToast(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AppToast(message: message, duration: duration, onDismissed: entry.remove),
  );
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({required this.message, required this.duration, required this.onDismissed});

  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast> with SingleTickerProviderStateMixin {
  static const _fade = Duration(milliseconds: 200);

  late final AnimationController _controller = AnimationController(vsync: this, duration: _fade);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(widget.duration);
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24 + padding.bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: Align(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xE6202020),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, decoration: TextDecoration.none),
                textAlign: TextAlign.center,
                child: Text(widget.message),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
