import 'package:flutter/widgets.dart';

/// Simple, framework-only startup error UI that works on all platforms.
///
/// Shows a friendly message and an expandable technical details area.
class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({super.key, required this.message, required this.details});

  final String message;
  final String details;

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF1A1A2E),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to start the application', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
                  const SizedBox(height: 12),
                  Text(widget.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFFB0B0B0), decoration: TextDecoration.none)),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: const Color(0xFF2A2A3A)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_expanded ? '▾' : '▸', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14)),
                        const SizedBox(width: 8),
                        const Text('Show technical details', style: TextStyle(color: Color(0xFFFFFFFF))),
                      ]),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFF0F0F1A),
                              padding: const EdgeInsets.all(12),
                              child: SingleChildScrollView(child: Text(widget.details, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFB0B0B0)))),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
