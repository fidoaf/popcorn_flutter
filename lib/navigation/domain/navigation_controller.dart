import 'package:collection/collection.dart';
import 'package:popcorn_flutter/home/domain/home_page.dart';
import 'package:popcorn_flutter/navigation/domain/navigation_route.dart';
import 'package:popcorn_flutter/not_found/domain/not_found_page.dart';
import 'package:popcorn_flutter/page/domain/view_page.dart';

abstract class NavigationController {
  final List<NavigationRoute> allowedRoutes = [
    NavigationRoute.home,
  ];

  NavigationRoute? getNavigationRouteByPath(String? routePath) {
    return allowedRoutes.firstWhereOrNull((route) => route.name == routePath);
  }

  ViewPage? generatePage(NavigationRoute? route);

  Future<NotFoundPage> showNotFoundPage();
  Future<HomePage> goToMainPage();
}
