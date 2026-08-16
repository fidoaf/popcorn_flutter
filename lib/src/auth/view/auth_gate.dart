import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';

/// Gates [child] behind authentication.
///
/// While [controller] reports no session, [loginBuilder] is shown on top of the
/// (still-mounted) navigator. Routes reported as public by [isPublicRoute] are
/// shown even when signed out, so pages like the privacy policy and terms of
/// service remain reachable. Rebuilds whenever the auth state or current route
/// changes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller, required this.loginBuilder, required this.child, this.currentRoute, this.isPublicRoute});

  final AuthController controller;
  final WidgetBuilder loginBuilder;
  final Widget child;
  final ValueListenable<String?>? currentRoute;
  final bool Function(String? routeName)? isPublicRoute;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, currentRoute]),
      builder: (context, _) {
        final isPublic = isPublicRoute?.call(currentRoute?.value) ?? false;
        final showLogin = !controller.isSignedIn && !isPublic;
        // The navigator (child) stays mounted at index 0 so the login footer can
        // push public pages onto it; the login screen is layered on top.
        return Stack(
          children: [
            child,
            if (showLogin) Positioned.fill(child: loginBuilder(context)),
          ],
        );
      },
    );
  }
}
