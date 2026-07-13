import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:popcorn_flutter/application/domain/application.dart';
import 'package:popcorn_flutter/landing/material/material_landing_page.dart';
import 'package:popcorn_flutter/navigation/material/material_navigation.dart';

abstract class MaterialApplication extends Application {
  final Completer<bool> _buildDone = Completer();
  late final MaterialApp _app;
  MaterialApplication({required super.configuration, required MaterialNavigationController navigationController}) {
    _app = MaterialApp(
      title: configuration.title,
      debugShowCheckedModeBanner: configuration.showDebugIndication,
      navigatorKey: navigationController.navigatorKey,
      home: _MaterialApplicationLoader(_buildDone),
      onGenerateRoute: (settings) {
        final targetPage = navigationController.generatePageByRouteSettings(settings);
        if (targetPage == null) {
          return null;
        }
        return MaterialPageRoute(
          builder: (context) => targetPage.content,
        );
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('NOT FOUND')),
          ),
        );
      },
    );
  }

  @override
  Future<bool> initialize() async {
    log('Initializing dependencies');
    WidgetsFlutterBinding.ensureInitialized();
    runApp(_app);
    return _buildDone.future;
  }

  MaterialApp get app => _app;
}

class _MaterialApplicationLoader extends StatelessWidget {
  final Completer<bool> _buildDone;
  const _MaterialApplicationLoader(this._buildDone);

  @override
  Widget build(BuildContext context) {
    if (!_buildDone.isCompleted) _buildDone.complete(true);
    return const MaterialLandingPage();
  }
}
