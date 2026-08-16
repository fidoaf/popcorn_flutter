import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';

/// Gates [child] behind authentication.
///
/// While [controller] reports no session, [loginBuilder] is shown instead of
/// [child]. Rebuilds whenever the auth state changes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller, required this.loginBuilder, required this.child});

  final AuthController controller;
  final WidgetBuilder loginBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: (context, _) => controller.isSignedIn ? child : loginBuilder(context));
  }
}
