import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/search/view/gui/app_search_form.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  //
  await ServiceLocator.init();

  //
  final home = ServiceLocator.window.handleView(const MediaSearchFormPage());

  //
  runApp(MaterialApp(navigatorKey: NavigationService.navigatorKey, debugShowCheckedModeBanner: false, theme: ThemeData.light(), darkTheme: ThemeData.dark(), themeMode: ThemeMode.system, home: home));
}
