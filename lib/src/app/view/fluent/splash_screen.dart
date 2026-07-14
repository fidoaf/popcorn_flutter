import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornFluentSplashScreen extends StatelessWidget {
  const PopcornFluentSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      content: SplashLayout(
        assetPath: SplashAssets.popcornGif,
        titleWidget: Text(AppTranslations.appTitle.trOf(context), style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.bold)),
        subtitleWidget: Text(AppTranslations.splashSubtitle.trOf(context), style: theme.typography.body),
      ),
    );
  }
}
