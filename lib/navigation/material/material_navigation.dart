import 'package:flutter/material.dart';
import 'package:popcorn_flutter/home/domain/home_page.dart';
import 'package:popcorn_flutter/navigation/domain/navigation_controller.dart';
import 'package:popcorn_flutter/navigation/domain/navigation_route.dart';
import 'package:popcorn_flutter/home/material/material_home_page.dart';
import 'package:popcorn_flutter/not_found/material/material_not_found_page.dart';
import 'package:popcorn_flutter/page/material/material_page.dart';

abstract class MaterialNavigationController extends NavigationController {
  static final Map<NavigationRoute, Widget Function()> _viewRouteGenerators = {
    NavigationRoute.home: () => const MaterialHomePage(),
  };

  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  MaterialNavigationController();

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  Map<NavigationRoute, Widget Function()> get viewPageRoute => _viewRouteGenerators;

  @override
  Future<MaterialNotFoundPage> showNotFoundPage() async {
    const page = MaterialNotFoundPage();
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => page, settings: RouteSettings(name: NavigationRoute.home.name)),
    );
    return page;
  }

  @override
  Future<HomePage> goToMainPage() async {
    const page = MaterialHomePage();
    _navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (context) => page, settings: RouteSettings(name: NavigationRoute.home.name)),
    );
    return page;
  }

  MaterialViewPage? generatePageByRouteSettings(RouteSettings settings) {
    final navigationRoute = _getNavigationRouteByRouteSetting(settings);
    return generatePage(navigationRoute);
  }

  @override
  MaterialViewPage? generatePage(NavigationRoute? route) {
    final targetPage = _viewRouteGenerators[route];
    if (targetPage == null) {
      return null;
    }
    return MaterialViewPage(targetPage);
  }

  NavigationRoute? _getNavigationRouteByRouteSetting(RouteSettings settings) {
    final routePath = settings.name;
    return getNavigationRouteByPath(routePath);
  }
}
