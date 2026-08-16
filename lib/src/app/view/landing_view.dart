import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/legal/legal.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Public landing page shown at `/` on every platform.
///
/// Describes the app and its features without requiring a sign-in, so visitors
/// (and search engines) can learn about Popcorn before entering the app. It
/// bakes in its own Material theme so it looks identical regardless of the host
/// app's design system (Material, Cupertino, macOS or Fluent).
class PopcornLandingView extends StatelessWidget {
  const PopcornLandingView({super.key, required this.onEnter, this.onOpenPrivacy, this.onOpenTerms});

  static const Color _background = Color(0xFF1A1A2E);

  final VoidCallback onEnter;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: _background);
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/icons/app_icon.png', width: 112, height: 112)),
                    const SizedBox(height: 24),
                    Text(
                      AppTranslations.appTitle.trOf(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppTranslations.landingTagline.trOf(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(AppTranslations.landingDescription.trOf(context), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 32),
                    _Feature(icon: Icons.local_movies, label: AppTranslations.landingFeatureBrowse.trOf(context)),
                    _Feature(icon: Icons.play_circle_outline, label: AppTranslations.landingFeatureTrailers.trOf(context)),
                    _Feature(icon: Icons.favorite_border, label: AppTranslations.landingFeatureFavorites.trOf(context)),
                    const SizedBox(height: 36),
                    FilledButton.icon(
                      onPressed: onEnter,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(AppTranslations.landingEnter.trOf(context)),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), textStyle: theme.textTheme.titleMedium),
                    ),
                    if (onOpenPrivacy != null || onOpenTerms != null) ...[
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (onOpenPrivacy != null) TextButton(onPressed: onOpenPrivacy, child: Text(LegalTranslations.privacyLink.trOf(context))),
                          if (onOpenPrivacy != null && onOpenTerms != null) Text('·', style: theme.textTheme.bodySmall),
                          if (onOpenTerms != null) TextButton(onPressed: onOpenTerms, child: Text(LegalTranslations.termsLink.trOf(context))),
                        ],
                      ),
                    ],
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

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
