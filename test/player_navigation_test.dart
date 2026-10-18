import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

void main() {
  for (final fromDetails in [false, true]) {
    testWidgets('episode replacements return Back directly to ${fromDetails ? 'details' : 'home'}', (tester) async {
      final auth = ValueNotifier(true);
      final historyUpdates = <Map<dynamic, dynamic>>[];
      Object? watchExtra;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') historyUpdates.add(call.arguments as Map<dynamic, dynamic>);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, null));
      final router = createAppRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        isSignedIn: () => true,
        authState: auth,
        initialLocation: AppRoutes.home,
        pageBuilder: (context, state, request) => MaterialPage<void>(
          key: state.pageKey,
          child: Scaffold(
            body: request is WatchRoute
                ? Builder(
                    builder: (context) {
                      watchExtra = state.extra;
                      return TextButton(
                        onPressed: () {
                          final season = request.season ?? 1;
                          final episode = request.episode ?? 1;
                          Router.neglect(context, () {
                            GoRouter.of(context).replace(
                              AppRoutes.watch(request.type, request.id, season: episode == 2 ? season + 1 : season, episode: episode == 2 ? 1 : episode + 1),
                              extra: state.extra,
                            );
                          });
                        },
                        child: Text('Watch ${request.season}:${request.episode}'),
                      );
                    },
                  )
                : Text(request is DetailsRoute ? 'Details' : 'Home'),
          ),
        ),
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      if (fromDetails) {
        router.push(AppRoutes.details(MediaType.tv, 42));
        await tester.pumpAndSettle();
      }
      const extra = 'preserved metadata';
      router.push(AppRoutes.watch(MediaType.tv, 42, season: 1, episode: 1), extra: extra);
      await tester.pumpAndSettle();
      for (final step in ['1:1', '1:2', '2:1']) {
        historyUpdates.clear();
        await tester.tap(find.text('Watch $step'));
        await tester.pumpAndSettle();
        expect(watchExtra, extra);
        expect(historyUpdates, isNotEmpty);
        expect(historyUpdates.last['replace'], isTrue);
      }
      expect(find.text('Watch 2:2'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text(fromDetails ? 'Details' : 'Home'), findsOneWidget);
      expect(find.textContaining('Watch'), findsNothing);
      if (fromDetails) {
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      }
      expect(router.canPop(), isFalse);
    });
  }
}
