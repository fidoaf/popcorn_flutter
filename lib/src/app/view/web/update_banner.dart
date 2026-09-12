import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/update/web_update_checker.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:web/web.dart' as web;

/// Overlays a dismissible banner over [child] when [checker] reports that a new
/// web build is available. Tapping reload performs a full page refresh so the
/// browser fetches the freshly deployed assets.
class WebUpdateBanner extends StatefulWidget {
  const WebUpdateBanner({super.key, required this.checker, required this.child});

  final WebUpdateChecker checker;
  final Widget child;

  @override
  State<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends State<WebUpdateBanner> {
  static final ThemeData _theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark);

  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.checker,
      builder: (context, child) {
        final show = widget.checker.updateAvailable && !_dismissed;
        return Stack(
          children: [
            child!,
            if (show) Positioned(left: 0, right: 0, top: 0, child: _banner(context)),
          ],
        );
      },
      child: widget.child,
    );
  }

  // Full page refresh so the browser fetches the freshly deployed assets.
  void _forceReload() => web.window.location.reload();

  Widget _banner(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Theme(
      data: _theme,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A45),
              borderRadius: radius,
              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.6)),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: _forceReload,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.system_update_alt, color: Colors.deepOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(AppTranslations.updateAvailableMessage.trOf(context), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _forceReload, child: Text(AppTranslations.updateReload.trOf(context))),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => setState(() => _dismissed = true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
