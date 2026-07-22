import 'package:flutter/cupertino.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_gate.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornCupertinoSplashScreen extends StatelessWidget {
  const PopcornCupertinoSplashScreen({super.key, this.child, this.minimumDuration = SplashGate.defaultMinimumDuration});

  /// Shown once [minimumDuration] has elapsed.
  final Widget? child;

  /// Minimum amount of time the splash screen stays visible.
  final Duration minimumDuration;

  @override
  Widget build(BuildContext context) {
    return SplashGate(
      minimumDuration: minimumDuration,
      splash: CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: SplashLayout(
          assetPath: SplashAssets.popcornGif,
          titleWidget: Text(AppTranslations.appTitle.trOf(context), style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle),
          subtitleWidget: Text(AppTranslations.splashSubtitle.trOf(context), style: CupertinoTheme.of(context).textTheme.textStyle),
        ),
      ),
      child: child,
    );
  }
}
