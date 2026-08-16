import 'package:flutter/widgets.dart';

/// A [NavigatorObserver] that exposes the name of the current top route.
///
/// The auth gate listens to this so that public pages (privacy, terms) can be
/// shown without signing in, while every other route stays behind the login
/// screen.
class CurrentRouteObserver extends NavigatorObserver {
  CurrentRouteObserver([String? initialRoute]) : routeName = ValueNotifier<String?>(initialRoute);

  final ValueNotifier<String?> routeName;

  void _update(Route<dynamic>? route) {
    final name = route is ModalRoute ? route.settings.name : null;
    // Defer so the notifier is never mutated while the navigator is building
    // its initial route stack (which would rebuild the gate mid-frame).
    WidgetsBinding.instance.addPostFrameCallback((_) => routeName.value = name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _update(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);
}
