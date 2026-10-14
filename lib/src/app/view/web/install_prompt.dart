import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:web/web.dart' as web;

/// Suggests installing the web app once in a regular browser tab.
class WebInstallPrompt extends StatefulWidget {
  const WebInstallPrompt({super.key, required this.isPwa, required this.child});

  final bool isPwa;
  final Widget child;

  @override
  State<WebInstallPrompt> createState() => _WebInstallPromptState();
}

class _WebInstallPromptState extends State<WebInstallPrompt> {
  static const _dismissedKey = 'popcorn.web-install-prompt.dismissed.v1';
  static final ThemeData _theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.light);

  late bool _dismissed;

  bool get _isIos => RegExp(r'iPhone|iPad|iPod').hasMatch(web.window.navigator.userAgent);

  @override
  void initState() {
    super.initState();
    _dismissed = widget.isPwa || web.window.localStorage.getItem(_dismissedKey) == 'true';
  }

  void _dismiss() {
    web.window.localStorage.setItem(_dismissedKey, 'true');
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: SafeArea(
              child: Center(
                child: Theme(
                  data: _theme,
                  child: Dialog(
                    backgroundColor: Colors.white,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              // No tooltip: this sits above the Navigator, so there is no Overlay.
                              child: IconButton(
                                onPressed: _dismiss,
                                icon: Icon(Icons.close, semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip),
                              ),
                            ),
                            Image.asset('assets/icons/app_icon.png', width: 72, height: 72),
                            const SizedBox(height: 16),
                            Text(
                              AppTranslations.installAppTitle.trOf(context),
                              style: const TextStyle(color: Color(0xFF222222), fontSize: 26, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppTranslations.installAppMessage.trOf(context),
                              style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                (_isIos ? AppTranslations.installIosInstructionsTitle : AppTranslations.installBrowserInstructionsTitle).trOf(context),
                                style: const TextStyle(color: Color(0xFF333333), fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_isIos) ...[
                              _InstructionRow(number: '1', text: AppTranslations.installIosInstructionShare.trOf(context)),
                              _InstructionRow(number: '2', text: AppTranslations.installIosInstructionHome.trOf(context)),
                              _InstructionRow(number: '3', text: AppTranslations.installIosInstructionAdd.trOf(context)),
                            ] else ...[
                              _InstructionRow(number: '1', text: AppTranslations.installBrowserInstructionMenu.trOf(context)),
                              _InstructionRow(number: '2', text: AppTranslations.installBrowserInstructionApp.trOf(context)),
                            ],
                            const SizedBox(height: 24),
                            const Divider(color: Color(0xFFE5E5E5)),
                            TextButton(
                              onPressed: _dismiss,
                              child: Text(AppTranslations.installLater.trOf(context), style: const TextStyle(color: Color(0xFF666666), fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ',
          style: const TextStyle(color: Color(0xFF333333), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF444444), fontSize: 16)),
        ),
      ],
    ),
  );
}
