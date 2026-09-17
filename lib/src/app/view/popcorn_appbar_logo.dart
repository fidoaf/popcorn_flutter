import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Small, unintrusive Popcorn logo for app bars.
///
/// Sits in the `actions` slot so it never displaces the automatic back button,
/// and navigates back to the home page when tapped.
class PopcornAppBarLogo extends StatelessWidget {
  const PopcornAppBarLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: AppTranslations.appTitle.trOf(context),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => context.go(AppRoutes.home),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icons/app_icon.png', width: size, height: size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
