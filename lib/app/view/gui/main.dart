import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/app/view/gui/splash_screen.dart';
import 'package:popcorn_flutter/search/view/gui/app_search_form.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';
import 'package:popcorn_flutter/window/tools/window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final windowManager = await WindowManager.getInstance();
  runApp(PopcornApp(home: windowManager.createMainView(const PopcornSplashScreen())));
}

class PopcornApp extends StatefulWidget {
  final Widget home;

  const PopcornApp({super.key, required this.home});

  @override
  State<PopcornApp> createState() => _PopcornAppState();
}

class _PopcornAppState extends State<PopcornApp> {
  static const int _minSplashDuration = 1000;

  late Widget _home;

  @override
  void initState() {
    super.initState();
    _home = widget.home;
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final splashStart = DateTime.now();
    await ServiceLocator.init();
    final elapsed = DateTime.now().difference(splashStart);
    if (elapsed < const Duration(milliseconds: _minSplashDuration)) {
      await Future.delayed(const Duration(milliseconds: _minSplashDuration) - elapsed);
    }
    if (!mounted) return;
    setState(() {
      _home = ServiceLocator.window.createMainView(const MediaSearchFormPage());
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: _home,
    );
  }
}
