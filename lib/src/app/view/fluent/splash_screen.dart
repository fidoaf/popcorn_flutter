import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_gate.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornFluentSplashScreen extends StatelessWidget {
  const PopcornFluentSplashScreen({super.key, this.child, this.minimumDuration = SplashGate.defaultMinimumDuration});

  /// Shown once [minimumDuration] has elapsed.
  final Widget? child;

  /// Minimum amount of time the splash screen stays visible.
  final Duration minimumDuration;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return SplashGate(
      minimumDuration: minimumDuration,
      splash: ScaffoldPage(
        content: SplashLayout(
          assetPath: SplashAssets.popcornGif,
          titleWidget: Text(AppTranslations.appTitle.trOf(context), style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.bold)),
          subtitleWidget: Text(AppTranslations.splashSubtitle.trOf(context), style: theme.typography.body),
        ),
      ),
      child: child,
    );
  }
}
