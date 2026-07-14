import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/splash_assets.dart';
import 'package:popcorn_flutter/src/app/view/splash_layout.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

class PopcornMaterialSplashScreen extends StatelessWidget {
  const PopcornMaterialSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SplashLayout(
        assetPath: SplashAssets.popcornGif,
        titleWidget: Text(AppTranslations.appTitle.trOf(context), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitleWidget: Text(AppTranslations.splashSubtitle.trOf(context), style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
