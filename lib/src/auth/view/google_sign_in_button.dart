import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "Sign in with Google" button rendered per Google's branding guidelines
/// (https://developers.google.com/identity/branding-guidelines).
///
/// Uses the neutral (light) button style — white surface, `#1F1F1F` label and
/// a `#747775` border — with the official four-colour "G" mark, Roboto Medium
/// label and hover/pressed state overlays. Built from foundational widgets so
/// the same branded button can be embedded in the Material, macOS and Fluent
/// login screens without altering the mark.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _hovered = false;
  bool _pressed = false;

  static const double _height = 44;
  static const double _radius = 4;
  static const double _logoSize = 20;
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFF747775);
  static const Color _label = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    // Google-specified state overlays for the neutral button.
    final Color? overlay = !enabled
        ? null
        : _pressed
        ? const Color(0x291F1F1F)
        : _hovered
        ? const Color(0x141F1F1F)
        : null;
    final surface = overlay == null ? _surface : Color.alphaBlend(overlay, _surface);

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: Container(
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: widget.busy
                ? const SizedBox(
                    width: _logoSize,
                    height: _logoSize,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_label)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/icons/google_g.svg', width: _logoSize, height: _logoSize),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _label, fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.25),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
