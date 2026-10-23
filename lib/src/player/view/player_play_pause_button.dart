import 'package:flutter/material.dart';

/// Keeps the transport layout stable without offering playback during loading.
class PlayerPlayPauseButton extends StatelessWidget {
  const PlayerPlayPauseButton({super.key, required this.loading, required this.playing, required this.onPressed, this.prominent = false});

  final bool loading;
  final bool playing;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final icon = playing ? Icons.pause : Icons.play_arrow;
    return Visibility(
      visible: !loading,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: prominent
          ? Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.all(64 * 0.18),
                  child: Icon(icon, color: Colors.white, size: 64 * 0.6),
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.white),
              iconSize: 22,
              splashRadius: 22,
            ),
    );
  }
}
