import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:popcorn_flutter/src/player/view/player_controls_scope.dart';

/// Floating close button shown in the top-right corner of the hosted player.
class PlayerCloseButton extends StatelessWidget {
  const PlayerCloseButton({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PlayerOverlayControls(
      child: Localizations.override(
        context: context,
        delegates: const [DefaultMaterialLocalizations.delegate],
        child: Theme(
          data: ThemeData.dark(),
          child: PointerInterceptor(
            child: Material(
              color: const Color(0xE817191E),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0x50FFFFFF)),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox.square(
                dimension: 44,
                child: IconButton(tooltip: 'Close', onPressed: onClose, icon: const Icon(Icons.close)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
