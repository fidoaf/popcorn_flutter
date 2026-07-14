import 'dart:async';

import 'package:flutter/widgets.dart';

/// Displays [splash] for at least [minimumDuration], then swaps to [child].
///
/// If [child] is `null`, the [splash] keeps being shown even after the
/// minimum duration elapses.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.splash, this.child, this.minimumDuration = defaultMinimumDuration});

  /// The default minimum amount of time a splash screen stays visible.
  static const Duration defaultMinimumDuration = Duration(seconds: 1);

  /// The splash content shown while waiting for [minimumDuration] to elapse.
  final Widget splash;

  /// The content shown once [minimumDuration] has elapsed.
  final Widget? child;

  /// The minimum amount of time [splash] remains visible.
  final Duration minimumDuration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  bool _minimumElapsed = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(SplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_minimumElapsed && oldWidget.minimumDuration != widget.minimumDuration) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer(widget.minimumDuration, () {
      if (mounted) {
        setState(() => _minimumElapsed = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (_minimumElapsed && child != null) {
      return child;
    }
    return widget.splash;
  }
}
