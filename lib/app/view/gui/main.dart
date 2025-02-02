import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/material.dart';
import 'package:popcorn_flutter/search/view/gui/app_search_view.dart';

const double _fixedWidth = 800;
const double _fixedHeight = 800;

void _adjustWindow() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix size
  const fixSize = Size(_fixedWidth, _fixedHeight);
  await DesktopWindow.setWindowSize(fixSize);
  await DesktopWindow.setMinWindowSize(fixSize);
  await DesktopWindow.setMaxWindowSize(fixSize);

  // await DesktopWindow.resetMaxWindowSize();
  // await DesktopWindow.toggleFullScreen();
  // bool isFullScreen = await DesktopWindow.getFullScreen();
  // await DesktopWindow.setFullScreen(true);
  // await DesktopWindow.setFullScreen(false);
  // bool hasBorders = await DesktopWindow.hasBorders;
  // await DesktopWindow.setBorders(false);
  // await DesktopWindow.setBorders(true);
  // await DesktopWindow.toggleBorders();
  // await DesktopWindow.focus();
}

void main(List<String> args) async {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const AppSearchView(),
    ),
  );

  //
  _adjustWindow();
}
