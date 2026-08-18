import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';

/// Entry point for the test web deployment (docs/test/).
/// Placeholder shell — replace `_TestDashboard` with the real test UI.
void main(List<String> args) async {
  if (!kIsWeb) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/app.env');
  runApp(const _PopcornTestApp());
}

class _PopcornTestApp extends StatelessWidget {
  const _PopcornTestApp();

  static const Color _background = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popcorn Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark),
      home: const _TestDashboard(),
    );
  }
}

class _TestDashboard extends StatelessWidget {
  const _TestDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PopcornTestApp._background,
      appBar: AppBar(backgroundColor: _PopcornTestApp._background, title: const Text('Popcorn Test')),
      body: const Center(child: Text('Test dashboard — coming soon')),
    );
  }
}
