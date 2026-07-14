import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_gate.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornWebSplashScreen extends StatelessWidget {
  const PopcornWebSplashScreen({super.key, this.child, this.minimumDuration = SplashGate.defaultMinimumDuration});

  /// Shown once [minimumDuration] has elapsed.
  final Widget? child;

  /// Minimum amount of time the splash screen stays visible.
  final Duration minimumDuration;

  @override
  Widget build(BuildContext context) {
    return SplashGate(
      minimumDuration: minimumDuration,
      child: child,
      splash: Container(
        color: const Color(0xFF1A1A2E),
        child: SplashLayout(
          assetPath: SplashAssets.popcornGif,
          titleWidget: Text(
            AppTranslations.appTitle.trOf(context),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF), decoration: TextDecoration.none),
          ),
          subtitleWidget: Text(
            AppTranslations.splashSubtitle.trOf(context),
            style: const TextStyle(fontSize: 14, color: Color(0xFFB0B0B0), decoration: TextDecoration.none),
          ),
        ),
      ),
    );
  }
}
