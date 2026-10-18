import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Shared email/password sign-in form.
class EmailPasswordForm extends StatefulWidget {
  const EmailPasswordForm({super.key, required this.controller, required this.busy, required this.onBusyChanged});

  final AuthController controller;
  final bool busy;
  final ValueChanged<bool> onBusyChanged;

  @override
  State<EmailPasswordForm> createState() => _EmailPasswordFormState();
}

class _EmailPasswordFormState extends State<EmailPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = null);
    widget.onBusyChanged(true);
    try {
      await widget.controller.signInWithEmail(_emailController.text, _passwordController.text);
    } catch (error) {
      if (mounted) setState(() => _error = AuthTranslations.authenticationErrorFor(context, error));
    } finally {
      widget.onBusyChanged(false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return AuthTranslations.enterEmail.trOf(context);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return AuthTranslations.invalidEmail.trOf(context);
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AuthTranslations.enterPassword.trOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.busy;
    return Localizations.override(
      context: context,
      delegates: GlobalMaterialLocalizations.delegates,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(filled: true, fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(AuthTranslations.emailPasswordDivider.trOf(context))),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: !disabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: _validateEmail,
                  decoration: InputDecoration(labelText: AuthTranslations.email.trOf(context), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  enabled: !disabled,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: AuthTranslations.password.trOf(context),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: (_obscurePassword ? AuthTranslations.showPassword : AuthTranslations.hidePassword).trOf(context),
                      onPressed: disabled ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: disabled ? null : _submit,
                    child: disabled
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(AuthTranslations.signInWithEmail.trOf(context)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
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
