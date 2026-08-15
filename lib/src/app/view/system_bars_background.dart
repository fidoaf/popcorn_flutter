import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paints the system status bar (notification bar) and navigation bar with the
/// app's general background color so they blend seamlessly with the content.
///
/// When [backgroundColor] is omitted the current theme's
/// [ColorScheme.surface] is used, so the bars follow light/dark theme changes.
class SystemBarsBackground extends StatelessWidget {
  const SystemBarsBackground({super.key, required this.child, this.backgroundColor});

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final color = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final barBrightness = ThemeData.estimateBrightnessForColor(color);
    // Icons/text need to contrast with the bar: dark background -> light icons.
    final iconBrightness = barBrightness == Brightness.dark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: color,
        systemNavigationBarColor: color,
        statusBarIconBrightness: iconBrightness,
        systemNavigationBarIconBrightness: iconBrightness,
        statusBarBrightness: barBrightness,
      ),
      child: child,
    );
  }
}
