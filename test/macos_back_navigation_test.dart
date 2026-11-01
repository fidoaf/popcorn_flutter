import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/app/routing/app_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

void main() {
  for (final deepLink in [false, true]) {
    testWidgets(
      'macOS toolbar back navigation ${deepLink ? 'from a deep link' : 'through nested pages'}',
      (tester) async {
        final auth = ValueNotifier(true);
        final router = createAppRouter(
          navigatorKey: GlobalKey<NavigatorState>(),
          isSignedIn: () => true,
          authState: auth,
          initialLocation: deepLink
              ? AppRoutes.details(MediaType.movie, 1)
              : AppRoutes.home,
          pageBuilder: (context, state, request) => CupertinoPage<void>(
            key: state.pageKey,
            child: MacosScaffold(
              toolBar: ToolBar(
                title: Text(
                  request is DetailsRoute ? 'Details ${request.id}' : 'Home',
                ),
                actions: [
                  CustomToolbarItem(
                    inToolbarBuilder: (_) => const Text('Logo'),
                  ),
                ],
              ),
              children: [ContentArea(builder: (_, __) => const SizedBox())],
            ),
          ),
        );
        addTearDown(router.dispose);
        addTearDown(auth.dispose);
        await tester.pumpWidget(MacosApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        if (!deepLink) {
          expect(find.byType(MacosBackButton), findsNothing);
          router.push(AppRoutes.details(MediaType.movie, 1));
          await tester.pumpAndSettle();
          router.push(AppRoutes.details(MediaType.movie, 2));
          await tester.pumpAndSettle();
          expect(find.text('Details 2'), findsOneWidget);
          await tester.tap(find.byType(MacosBackButton));
          await tester.pumpAndSettle();
        }

        expect(find.text('Details 1'), findsOneWidget);
        expect(find.text('Logo'), findsOneWidget);
        expect(find.byType(MacosBackButton), findsOneWidget);
        await tester.tap(find.byType(MacosBackButton));
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.byType(MacosBackButton), findsNothing);
      },
    );
  }
}
