import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Fluent (Windows) sign-in screen offering Google as the only sign-in method.
class FluentLoginView extends StatefulWidget {
  const FluentLoginView({super.key, required this.controller});

  final AuthController controller;

  @override
  State<FluentLoginView> createState() => _FluentLoginViewState();
}

class _FluentLoginViewState extends State<FluentLoginView> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.signInWithGoogle();
    } catch (_) {
      if (mounted) setState(() => _error = AuthTranslations.signInError.trOf(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage(
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.my_movies_t_v, size: 64, color: theme.accentColor),
                const SizedBox(height: 16),
                Text(AppTranslations.appTitle.trOf(context), style: theme.typography.title),
                const SizedBox(height: 8),
                Text(AuthTranslations.signInSubtitle.trOf(context), textAlign: TextAlign.center, style: theme.typography.body),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy) const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2)) else const Icon(FluentIcons.signin),
                      const SizedBox(width: 8),
                      Text(AuthTranslations.signInWithGoogle.trOf(context)),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
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
