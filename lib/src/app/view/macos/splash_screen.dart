import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_gate.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornMacosSplashScreen extends StatelessWidget {
  const PopcornMacosSplashScreen({super.key, this.child, this.minimumDuration = SplashGate.defaultMinimumDuration});

  /// Shown once [minimumDuration] has elapsed.
  final Widget? child;

  /// Minimum amount of time the splash screen stays visible.
  final Duration minimumDuration;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return SplashGate(
      minimumDuration: minimumDuration,
      splash: MacosScaffold(
        children: [
          ContentArea(
            builder: (context, _) => SplashLayout(
              assetPath: SplashAssets.popcornGif,
              titleWidget: Text(AppTranslations.appTitle.trOf(context), style: typography.largeTitle.copyWith(fontWeight: FontWeight.bold)),
              subtitleWidget: Text(AppTranslations.splashSubtitle.trOf(context), style: typography.body),
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}
