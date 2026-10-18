import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/home/view/browse_home_view.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_channel.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_controller.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_page.dart';

final channel = LiveTvChannel(id: 'Example.fr', name: 'Example TV', streamUrl: Uri.https('example.com', '/live.m3u8'));

void main() {
  testWidgets('country names and search follow locale changes without resetting the selected country', (tester) async {
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'channels': [],
            'countries': [
              {
                'code': 'FR',
                'name': 'France',
                'flag': '🇫🇷',
                'names': {'en': 'France', 'es': 'Francia', 'ca': 'França'},
              },
              {
                'code': 'US',
                'name': 'United States',
                'flag': '🇺🇸',
                'names': {'en': 'United States', 'es': 'Estados Unidos', 'ca': 'Estats Units'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.selectCountry('FR');
    for (final entry in [
      ('en', 'France', 'United States', 'united'),
      ('es', 'Francia', 'Estados Unidos', 'estados'),
      ('ca', 'França', 'Estats Units', 'estats'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.$1),
          supportedLocales: const [Locale('en'), Locale('es'), Locale('ca')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: LiveTvSection(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '🇫🇷  ${entry.$2}');
      expect(controller.selectedCountry, 'FR');
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), entry.$4);
      await tester.pumpAndSettle();
      expect(find.text('🇺🇸  ${entry.$3}').hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('country selector starts empty, displays flags and names, and filters or resets the row', (tester) async {
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient((request) async {
        final selected = request.url.queryParameters['country'];
        return http.Response(
          jsonEncode({
            'channels': [
              if (selected == null || selected == 'FR') {'id': 'fr', 'name': 'French TV', 'country': 'FR', 'url': 'https://example.com/fr.m3u8'},
              if (selected == null || selected == 'US') {'id': 'us', 'name': 'American TV', 'country': 'US', 'url': 'https://example.com/us.m3u8'},
            ],
            'countries': [
              {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
              {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LiveTvSection(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.selectedCountry, isNull);
    expect(tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>)).initialSelection, '');
    expect(find.text('French TV'), findsOneWidget);
    expect(find.text('American TV'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('🇫🇷  France').hitTestable(), findsOneWidget);
    expect(find.text('🇺🇸  United States').hitTestable(), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'fRaN');
    await tester.pumpAndSettle();
    expect(find.text('🇫🇷  France').hitTestable(), findsOneWidget);
    expect(find.text('🇺🇸  United States').hitTestable(), findsNothing);
    expect(controller.selectedCountry, isNull);
    await tester.tap(find.text('🇫🇷  France').last);
    await tester.pumpAndSettle();
    expect(controller.selectedCountry, 'FR');
    expect(find.text('French TV'), findsOneWidget);
    expect(find.text('American TV'), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'us');
    await tester.pumpAndSettle();
    expect(find.text('🇺🇸  United States').hitTestable(), findsOneWidget);
    expect(find.text('🇫🇷  France').hitTestable(), findsNothing);
    await tester.enterText(find.byType(TextField), 'no matching country');
    await tester.pumpAndSettle();
    expect(find.text('All countries').hitTestable(), findsOneWidget);
    await tester.tap(find.text('All countries').last);
    await tester.pumpAndSettle();
    expect(controller.selectedCountry, isNull);
    expect(find.text('American TV'), findsOneWidget);
    expect(find.text('French TV'), findsOneWidget);
  });

  testWidgets('Live TV country header fits a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LiveTvController(serverToken: '', client: MockClient((_) async => http.Response('{"channels":[]}', 200)));
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LiveTvSection(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Live TV'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'All countries');
    expect(tester.takeException(), isNull);
  });

  testWidgets('card tap opens details while Play goes straight to watch', (tester) async {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SizedBox(width: 164, height: 142, child: LiveTvChannelCard(channel: channel)),
          ),
        ),
        GoRoute(
          path: '/live-tv/:id',
          builder: (context, state) {
            expect(state.extra, channel);
            return const Scaffold(body: Text('Details destination'));
          },
        ),
        GoRoute(
          path: '/live-tv/:id/watch',
          builder: (context, state) {
            expect(state.extra, channel);
            return const Scaffold(body: Text('Watch destination'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Example TV'));
    await tester.pumpAndSettle();
    expect(find.text('Details destination'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    await tester.pumpAndSettle();
    expect(find.text('Watch destination'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.liveTvWatch(channel.id));
  });

  testWidgets('details shows channel info and real EPG below the Play button', (tester) async {
    final controller = LiveTvController(
      serverToken: 'test-token',
      client: MockClient((request) async {
        expect(request.url.path, '/live-tv/epg');
        expect(request.url.queryParameters['channel'], channel.id);
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          '{"programmes":[{"title":"Evening news","description":"Daily headlines","start":"2026-10-15T18:00:00Z","end":"2026-10-15T19:00:00Z"}]}',
          200,
        );
      }),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LiveTvPage(channelId: channel.id, channel: channel, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example TV'), findsNWidgets(2));
    expect(find.text('Evening news'), findsOneWidget);
    expect(find.text('Daily headlines'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Programme guide')).dy, greaterThan(tester.getTopLeft(find.text('Play')).dy));
  });

  testWidgets('EPG failures show Retry and empty results show unavailable', (tester) async {
    var failed = true;
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient((request) async => failed ? http.Response('', 502) : http.Response('{"programmes":[]}', 200)),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LiveTvPage(channelId: channel.id, channel: channel, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load the programme guide.'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No programme guide is available for this channel.'), findsOneWidget);
  });

  testWidgets('details reload resolves its channel and Play opens watch', (tester) async {
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('/epg')
              ? '{"programmes":[]}'
              : '{"channels":[{"id":"Example.fr","name":"Example TV","url":"https://example.com/live.m3u8"}]}',
          200,
        ),
      ),
    );
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.liveTvDetails(channel.id),
      routes: [
        GoRoute(
          path: '/live-tv/:id',
          builder: (context, state) => LiveTvPage(channelId: state.pathParameters['id']!, controller: controller),
        ),
        GoRoute(
          path: '/live-tv/:id/watch',
          builder: (context, state) => const Scaffold(body: Text('Watch destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Example TV'), findsNWidgets(2));
    expect(find.text('No programme guide is available for this channel.'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Watch destination'), findsOneWidget);
  });
}
