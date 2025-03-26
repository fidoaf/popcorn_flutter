import 'package:flutter/material.dart';
import 'package:popcorn_flutter/window/core/model/window_handler.dart';
import 'package:window_manager/window_manager.dart';

class WindowManager extends WindowHandler {
  static const double _fixedWidth = 800;
  static const double _fixedHeight = 800;

  static final WindowManager _singleton = WindowManager._internal();

  factory WindowManager._() {
    return _singleton;
  }

  WindowManager._internal();

  static Future<WindowManager> getInstance() async {
    // Fix size
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(title: 'Popcorn', center: true, size: Size(_fixedWidth, _fixedHeight));

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.setPreventClose(true);

    return WindowManager._();
  }

  @override
  Widget handleView(Widget view) {
    return _HandledView(view);
  }
}

class _HandledView extends StatefulWidget {
  final Widget child;
  const _HandledView(this.child);

  @override
  _HandledViewState createState() => _HandledViewState();
}

class _HandledViewState extends State<_HandledView> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Are you sure you want to close this window?'),
            actions: [
              TextButton(
                child: const Text('No'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Yes'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
