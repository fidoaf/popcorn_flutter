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

  static const Color _background = Color(0xFF0F1014);
  static const Color _surface = Color(0xFF16181F);
  static const double _maxContentWidth = 1200;
  static const double _wideBreakpoint = 900;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(isWide: isWide, onEnter: onEnter),
                    _HeroSection(isWide: isWide, onEnter: onEnter),
                    _FeaturesSection(isWide: isWide),
                    _HighlightsSection(isWide: isWide),
                    _Footer(onOpenPrivacy: onOpenPrivacy, onOpenTerms: onOpenTerms),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Centers section content and caps it to a comfortable reading width.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.color, this.padding});

  final Widget child;
  final Color? color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PopcornLandingView._maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isWide, required this.onEnter});

  final bool isWide;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PopcornLandingView._maxContentWidth),
          child: Row(
            children: [
              _BrandLogo(),
              if (isWide) ...[
                const SizedBox(width: 32),
                _NavLink(label: AppTranslations.landingNavHome.trOf(context), onTap: onEnter),
                _NavLink(label: AppTranslations.landingNavMovies.trOf(context), onTap: onEnter),
                _NavLink(label: AppTranslations.landingNavTvShows.trOf(context), onTap: onEnter),
              ],
              const Spacer(),
              IconButton(
                onPressed: onEnter,
                icon: const Icon(Icons.search),
                color: Colors.white70,
                tooltip: AppTranslations.landingBrowseCatalog.trOf(context),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onEnter,
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                child: Text(AppTranslations.landingEnter.trOf(context), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icons/app_icon.png', width: 32, height: 32)),
        const SizedBox(width: 10),
        Text(AppTranslations.appTitle.trOf(context), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: Colors.white70),
      child: Text(label),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.isWide, required this.onEnter});

  final bool isWide;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C1030), Color(0xFF0F1014)]),
      ),
      child: _Section(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(flex: 5, child: _PosterCollage()),
                  const SizedBox(width: 48),
                  Expanded(flex: 4, child: _HeroText(onEnter: onEnter)),
                ],
              )
            : Column(
                children: [
                  const _PosterCollage(),
                  const SizedBox(height: 40),
                  _HeroText(onEnter: onEnter),
                ],
              ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppTranslations.landingHeroTitle.trOf(context), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, height: 1.1)),
        const SizedBox(height: 20),
        Text(AppTranslations.landingHeroSubtitle.trOf(context), style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5)),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: onEnter,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          child: Text(AppTranslations.landingEnterFree.trOf(context)),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onEnter,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          ),
          child: Text(AppTranslations.landingBrowseCatalog.trOf(context)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.verified_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(AppTranslations.landingFreeTag.trOf(context), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Decorative grid of public-domain classic movie posters (bundled locally).
class _PosterCollage extends StatelessWidget {
  const _PosterCollage();

  // Public-domain posters sourced from Wikimedia Commons (see assets/posters/CREDITS.txt).
  static const List<String> assets = [
    'assets/posters/the_kid_1921.jpg',
    'assets/posters/caligari_1920.jpg',
    'assets/posters/his_girl_friday_1940.jpg',
    'assets/posters/charade_1963.jpg',
    'assets/posters/plan9_1959.jpg',
    'assets/posters/phantom_opera_1925.jpg',
    'assets/posters/frankenstein_1931.jpg',
    'assets/posters/night_living_dead_1968.jpg',
    'assets/posters/gold_rush_1925.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2 / 3),
      itemBuilder: (context, index) => _PosterTile(asset: assets[index]),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppTranslations.landingFeaturesTitle.trOf(context), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.2)),
        const SizedBox(height: 16),
        Text(AppTranslations.landingFeaturesBody.trOf(context), style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5)),
      ],
    );

    final chips = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _FeatureChip(icon: Icons.local_movies, label: AppTranslations.landingNavMovies.trOf(context)),
        _FeatureChip(icon: Icons.live_tv, label: AppTranslations.landingNavTvShows.trOf(context)),
        _FeatureChip(icon: Icons.play_circle_outline, label: AppTranslations.landingFeatureTrailers.trOf(context)),
        _FeatureChip(icon: Icons.favorite_border, label: AppTranslations.landingFeatureFavorites.trOf(context)),
        _FeatureChip(icon: Icons.history, label: AppTranslations.landingFeatureBrowse.trOf(context)),
        _FeatureChip(icon: Icons.public, label: AppTranslations.landingFreeTag.trOf(context)),
      ],
    );

    return _Section(
      color: PopcornLandingView._surface,
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: heading),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: chips),
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 32), chips]),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: PopcornLandingView._background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        ],
      ),
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final highlights = [
      _Highlight(
        icon: Icons.local_movies,
        title: AppTranslations.landingFeatureBrowse.trOf(context),
        body: AppTranslations.landingFeatureBrowseBody.trOf(context),
      ),
      _Highlight(
        icon: Icons.play_circle_outline,
        title: AppTranslations.landingFeatureTrailers.trOf(context),
        body: AppTranslations.landingFeatureTrailersBody.trOf(context),
      ),
      _Highlight(
        icon: Icons.favorite_border,
        title: AppTranslations.landingFeatureFavorites.trOf(context),
        body: AppTranslations.landingFeatureFavoritesBody.trOf(context),
      ),
    ];

    return _Section(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < highlights.length; i++) ...[if (i > 0) const SizedBox(width: 32), Expanded(child: highlights[i])],
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < highlights.length; i++) ...[if (i > 0) const SizedBox(height: 36), highlights[i]],
              ],
            ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withValues(alpha: 0.15)),
          child: Icon(icon, color: theme.colorScheme.primary, size: 34),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({this.onOpenPrivacy, this.onOpenTerms});

  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      color: PopcornLandingView._surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        children: [
          _BrandLogo(),
          if (onOpenPrivacy != null || onOpenTerms != null) ...[
            const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          Text(
            AppTranslations.landingFooterRights.trOf(context),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
