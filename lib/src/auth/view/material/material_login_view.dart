import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:popcorn_flutter/src/legal/legal.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Material sign-in screen offering Google as the only sign-in method.
/// Shared by the Android, TV and web entry points.
class MaterialLoginView extends StatefulWidget {
  const MaterialLoginView({super.key, required this.controller, this.onOpenPrivacy, this.onOpenTerms});

  final AuthController controller;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenTerms;

  @override
  State<MaterialLoginView> createState() => _MaterialLoginViewState();
}

class _MaterialLoginViewState extends State<MaterialLoginView> {
  bool _busy = false;
  String? _error;
  bool _handledRedirectError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledRedirectError) return;
    _handledRedirectError = true;
    final detail = widget.controller.consumeOAuthError();
    if (detail != null) _error = AuthTranslations.signInErrorWithDetail(context, detail);
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.signInWithGoogle();
    } catch (error) {
      if (mounted) setState(() => _error = AuthTranslations.signInErrorFor(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_movies, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(AppTranslations.appTitle.trOf(context), style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(AuthTranslations.signInSubtitle.trOf(context), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                  label: Text(AuthTranslations.signInWithGoogle.trOf(context)),
                ),
                if (AuthController.guestAccessAllowed) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : widget.controller.continueAsGuest,
                    icon: const Icon(Icons.person_outline),
                    label: Text(AuthTranslations.continueAsGuest.trOf(context)),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (widget.onOpenPrivacy != null || widget.onOpenTerms != null) ...[
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.onOpenPrivacy != null) TextButton(onPressed: widget.onOpenPrivacy, child: Text(LegalTranslations.privacyLink.trOf(context))),
                      if (widget.onOpenPrivacy != null && widget.onOpenTerms != null) Text('·', style: theme.textTheme.bodySmall),
                      if (widget.onOpenTerms != null) TextButton(onPressed: widget.onOpenTerms, child: Text(LegalTranslations.termsLink.trOf(context))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
