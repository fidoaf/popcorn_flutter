import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_kit/media_kit.dart';
import 'package:popcorn_flutter/src/app/routing/app_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/home/view/browse_home_view.dart';
import 'package:popcorn_flutter/src/radio/radio_controller.dart';
import 'package:popcorn_flutter/src/radio/radio_page.dart';
import 'package:popcorn_flutter/src/radio/radio_station.dart';

final station = RadioStation(
  id: '1cfb151d-a341-11e9-a787-52543be04c81',
  name: 'Test Radio',
  streamUrl: Uri.https('example.com', '/radio.mp3'),
  country: 'France',
  codec: 'MP3',
  bitrate: 128,
);

class _Streams extends Fake implements PlayerStream {
  final playingEvents = StreamController<bool>.broadcast();
  final bufferingEvents = StreamController<bool>.broadcast();
  final errorEvents = StreamController<String>.broadcast();

  @override
  Stream<bool> get playing => playingEvents.stream;
  @override
  Stream<bool> get buffering => bufferingEvents.stream;
  @override
  Stream<String> get error => errorEvents.stream;
}

class _Player extends Fake implements Player {
  @override
  final _Streams stream = _Streams();
  Playable? opened;
  bool disposed = false;
  double volume = 100;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened = playable;
    stream.playingEvents.add(play);
  }

  @override
  Future<void> play() async => stream.playingEvents.add(true);
  @override
  Future<void> pause() async => stream.playingEvents.add(false);
  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stream.playingEvents.close();
    await stream.bufferingEvents.close();
    await stream.errorEvents.close();
  }
}

void main() {
  testWidgets('radio country selector searches localized names and codes, filters stations and clears', (tester) async {
    final controller = RadioController(
      serverToken: '',
      client: MockClient((request) async {
        final selected = request.url.queryParameters['country'];
        return http.Response(
          jsonEncode({
            'stations': [
              if (selected == null || selected == 'FR') {'id': 'fr', 'name': 'French Radio', 'url': station.streamUrl.toString()},
              if (selected == null || selected == 'ES') {'id': 'es', 'name': 'Spanish Radio', 'url': station.streamUrl.toString()},
            ],
            'countries': [
              {
                'code': 'FR',
                'name': 'France',
                'flag': '🇫🇷',
                'names': {'es': 'Francia', 'ca': 'França'},
              },
              {
                'code': 'ES',
                'name': 'Spain',
                'flag': '🇪🇸',
                'names': {'es': 'España', 'ca': 'Espanya'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(controller.dispose);
    await controller.load();
    for (final entry in [('es', 'España', 'Todos los países'), ('ca', 'Espanya', 'Tots els països')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.$1),
          supportedLocales: const [Locale('en'), Locale('es'), Locale('ca')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: RadioSection(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, entry.$3);
      expect(controller.selectedCountry, isNull);
      expect(find.text('French Radio'), findsOneWidget);
      expect(find.text('Spanish Radio'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), entry.$2.toUpperCase());
      await tester.pumpAndSettle();
      expect(find.text('🇪🇸  ${entry.$2}').hitTestable(), findsOneWidget);
      expect(find.textContaining('🇫🇷').hitTestable(), findsNothing);
      expect(controller.selectedCountry, isNull);
      await tester.tap(find.text('🇪🇸  ${entry.$2}').last);
      await tester.pumpAndSettle();
      expect(controller.selectedCountry, 'ES');
      expect(find.text('Spanish Radio'), findsOneWidget);
      expect(find.text('French Radio'), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'fr');
      await tester.pumpAndSettle();
      expect(find.textContaining('🇫🇷').hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no matching country');
      await tester.pumpAndSettle();
      expect(find.text(entry.$3).hitTestable(), findsOneWidget);
      await tester.tap(find.text(entry.$3).last);
      await tester.pumpAndSettle();
      expect(controller.selectedCountry, isNull);
      expect(find.text('French Radio'), findsOneWidget);
    }
    await controller.selectCountry('FR');
    for (final entry in [('es', 'Francia'), ('ca', 'França')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.$1),
          supportedLocales: const [Locale('en'), Locale('es'), Locale('ca')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: RadioSection(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '🇫🇷  ${entry.$2}');
      expect(controller.selectedCountry, 'FR');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('radio section handles failure, retry, empty results and localized titles', (tester) async {
    var failed = true;
    final controller = RadioController(
      serverToken: '',
      client: MockClient((_) async => http.Response(failed ? '' : '{"stations":[]}', failed ? 503 : 200)),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RadioSection(controller: controller)),
      ),
    );
    expect(find.text('Radio stations'), findsOneWidget);
    expect(find.text('Radio stations are unavailable right now.'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No radio stations are available.'), findsOneWidget);
    for (final entry in [('es', 'Emisoras de radio'), ('ca', 'Emissores de ràdio')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.$1),
          supportedLocales: const [Locale('en'), Locale('es'), Locale('ca')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: RadioSection(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
    }
  });

  testWidgets('radio row fits a narrow viewport and station cards open the shared radio route', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = RadioController(
      serverToken: '',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'stations': [
              {'id': station.id, 'name': station.name, 'url': station.streamUrl.toString(), 'country': 'France'},
            ],
          }),
          200,
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final auth = ValueNotifier(true);
    addTearDown(auth.dispose);
    final router = createAppRouter(
      navigatorKey: GlobalKey<NavigatorState>(),
      pageBuilder: (context, state, request) => MaterialPage(
        child: Scaffold(body: RadioSection(controller: controller)),
      ),
      isSignedIn: () => true,
      authState: auth,
      initialLocation: '/home',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Test Radio'), findsOneWidget);
    expect(find.byIcon(Icons.radio), findsOneWidget);
    await tester.tap(find.text('Test Radio'));
    await tester.pumpAndSettle();
    expect(find.byType(RadioPage), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.radio(station.id));
    expect(tester.takeException(), isNull);
  });

  testWidgets('radio page resolves a cold station, plays, pauses, adjusts volume and disposes audio', (tester) async {
    final requests = <Uri>[];
    final controller = RadioController(
      serverToken: '',
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/play')
                ? {'url': station.streamUrl.toString()}
                : {
                    'stations': [
                      {'id': station.id, 'name': station.name, 'url': station.streamUrl.toString(), 'codec': 'MP3', 'bitrate': 128},
                    ],
                  },
          ),
          200,
        );
      }),
    );
    addTearDown(controller.dispose);
    final player = _Player();
    await tester.pumpWidget(
      MaterialApp(
        home: RadioPage(stationId: station.id, controller: controller, createPlayer: () => player),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests.single.queryParameters['station'], station.id);
    expect(find.text('MP3 · 128 kbps'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect((player.opened as Media).uri, station.streamUrl.toString());
    expect(requests.last.path, '/radio/play');
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    expect(requests.where((uri) => uri.path.endsWith('/play')), hasLength(1));
    tester.widget<Slider>(find.byType(Slider)).onChanged!(45);
    await tester.pumpAndSettle();
    expect(player.volume, 45);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(player.disposed, isTrue);
  });

  testWidgets('radio playback errors are visible and can be retried', (tester) async {
    var failed = true;
    var starts = 0;
    final controller = RadioController(
      serverToken: '',
      client: MockClient((_) async {
        starts += 1;
        return failed ? http.Response('', 502) : http.Response(jsonEncode({'url': station.streamUrl.toString()}), 200);
      }),
    );
    addTearDown(controller.dispose);
    final player = _Player();
    await tester.pumpWidget(
      MaterialApp(
        home: RadioPage(stationId: station.id, station: station, controller: controller, createPlayer: () => player),
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to play this station. Try again or choose another station.'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    expect(starts, 2);
    player.stream.errorEvents.add('Stream unavailable');
    await tester.pumpAndSettle();
    expect(find.text('Unable to play this station. Try again or choose another station.'), findsOneWidget);
  });
}
