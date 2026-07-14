import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_gate.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornMaterialSplashScreen extends StatelessWidget {
  const PopcornMaterialSplashScreen({super.key, this.child, this.minimumDuration = SplashGate.defaultMinimumDuration});

  /// Shown once [minimumDuration] has elapsed.
  final Widget? child;

  /// Minimum amount of time the splash screen stays visible.
  final Duration minimumDuration;

  @override
  Widget build(BuildContext context) {
    return SplashGate(
      minimumDuration: minimumDuration,
      child: child,
      splash: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SplashLayout(
          assetPath: SplashAssets.popcornGif,
          titleWidget: Text(AppTranslations.appTitle.trOf(context), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          subtitleWidget: Text(AppTranslations.splashSubtitle.trOf(context), style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}
