import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';

/// Builds the platform-specific [Page] for a resolved [AppRouteRequest].
///
/// The concrete media item / video passed while navigating is available as
/// `state.extra`; a cold-start deep link has `null` extra and is re-fetched.
typedef AppPageBuilder = Page<void> Function(BuildContext context, GoRouterState state, AppRouteRequest request);

/// Exposes the router's current location as a [ValueListenable] so the
/// route-aware [AuthGate] can react to navigation.
class RouterLocationListenable extends ValueNotifier<String?> {
  RouterLocationListenable(this._provider) : super(_provider.value.uri.toString()) {
    _provider.addListener(_sync);
  }

  final RouteInformationProvider _provider;

  void _sync() => value = _provider.value.uri.toString();

  @override
  void dispose() {
    _provider.removeListener(_sync);
    super.dispose();
  }
}

/// Creates the app's [GoRouter], shared by every platform entry point.
///
/// Routing (paths, parsing, auth redirect, deep-link seeding) lives here;
/// callers only supply [pageBuilder] to wrap each page in their UI toolkit's
/// [Page] type. Deep links to a leaf route (details, watch, …) are opened on
/// top of the home route so Back returns there.
GoRouter createAppRouter({
  required GlobalKey<NavigatorState> navigatorKey,
  required AppPageBuilder pageBuilder,
  required bool Function() isSignedIn,
  required String initialLocation,
}) {
  // Navigation uses `push` (ImperativeRouteMatch); without this the browser URL
  // stays on the base location instead of the pushed route.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final request = AppRoutes.parse(initialLocation);
  final seedsHome = request is DetailsRoute || request is WatchRoute || request is FavoritesRoute || request is HistoryRoute || request is TrailerRoute;

  GoRoute route(String path) => GoRoute(path: path, pageBuilder: (context, state) => pageBuilder(context, state, AppRoutes.parse(state.uri.toString())));

  final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: seedsHome ? AppRoutes.home : initialLocation,
    overridePlatformDefaultLocation: true,
    redirect: (context, state) {
      // Signed-in users skip the public landing page.
      if (state.uri.path == AppRoutes.landing && isSignedIn()) return AppRoutes.home;
      return null;
    },
    errorPageBuilder: (context, state) => pageBuilder(context, state, const HomeRoute()),
    routes: [
      route('/'),
      route('/home'),
      route('/favorites'),
      route('/history'),
      route('/privacy'),
      route('/terms'),
      route('/trailer'),
      route('/search/:type'),
      route('/details/:type/:id'),
      route('/watch/:type/:id'),
    ],
  );

  if (seedsHome) {
    WidgetsBinding.instance.addPostFrameCallback((_) => router.push(initialLocation));
  }
  return router;
}
