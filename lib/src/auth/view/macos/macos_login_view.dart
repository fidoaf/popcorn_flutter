import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// macOS sign-in screen offering Google as the only sign-in method.
class MacosLoginView extends StatefulWidget {
  const MacosLoginView({super.key, required this.controller});

  final AuthController controller;

  @override
  State<MacosLoginView> createState() => _MacosLoginViewState();
}

class _MacosLoginViewState extends State<MacosLoginView> {
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
    final theme = MacosTheme.of(context);
    return MacosScaffold(
      children: [
        ContentArea(
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.film, size: 64, color: theme.primaryColor),
                    const SizedBox(height: 16),
                    Text(AppTranslations.appTitle.trOf(context), style: theme.typography.largeTitle),
                    const SizedBox(height: 8),
                    Text(AuthTranslations.signInSubtitle.trOf(context), textAlign: TextAlign.center, style: theme.typography.body),
                    const SizedBox(height: 32),
                    PushButton(
                      controlSize: ControlSize.large,
                      onPressed: _busy ? null : _signIn,
                      child: _busy ? const SizedBox(width: 16, height: 16, child: ProgressCircle()) : Text(AuthTranslations.signInWithGoogle.trOf(context)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.typography.body.copyWith(color: MacosColors.systemRedColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
