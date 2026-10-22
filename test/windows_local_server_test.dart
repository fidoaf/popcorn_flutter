@TestOn('windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/player/infrastructure/local_server_preference.dart';
import 'package:popcorn_flutter/src/player/infrastructure/windows_local_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final overrides = HttpOverrides.current;
  setUp(() => HttpOverrides.global = null);
  tearDown(() => HttpOverrides.global = overrides);

  test('local mode is opt-in and its random token is stable across restarts', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await LocalServerPreference.isEnabled(), isFalse);
    await LocalServerPreference.setEnabled(true);
    expect(await LocalServerPreference.isEnabled(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    final token = await WindowsLocalServer.loadToken(prefs);
    expect(base64Url.decode(token), hasLength(32));
    expect(await WindowsLocalServer.loadToken(prefs), token);
    await LocalServerPreference.setEnabled(false);
    expect(await LocalServerPreference.isEnabled(), isFalse);
  });

  for (final authorized in [true, false]) {
    test(
      'existing ${authorized ? 'compatible' : 'unauthorized'} server is ${authorized ? 'reused, never stopped' : 'reported without launching a process'}',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var requests = 0;
        server.listen((request) async {
          requests++;
          if (request.uri.path == '/health') {
            request.response.write('ok');
          } else {
            expect(request.headers.value('Authorization'), 'Bearer test-token');
            request.response.statusCode = authorized ? 200 : 401;
            request.response.write(
              jsonEncode({
                'providers': [
                  {'id': 'test'},
                ],
                'defaultProvider': 'test',
              }),
            );
          }
          await request.response.close();
        });
        final manager = WindowsLocalServer(bundleDirectory: Directory('missing-bundle'), token: 'test-token', port: server.port);
        if (authorized) {
          await manager.start();
          await manager.stop();
          expect((await http.get(Uri.parse('${manager.serverUrl}/health'))).statusCode, 200);
          expect(requests, 3);
        } else {
          await expectLater(manager.start(), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('authentication'))));
          expect(requests, 2);
        }
      },
    );
  }

  test('missing bundle fails explicitly without changing to a hosted endpoint', () async {
    final port = await _freePort();
    final manager = WindowsLocalServer(bundleDirectory: Directory('missing-bundle'), token: 'test', port: port);
    await expectLater(manager.start(), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('bundle is missing'))));
  });

  final bundle = Directory('build\\windows-server').absolute;
  test(
    'bundled Node server starts, authenticates, is reused, and shuts down with its owner',
    () async {
      final manager = WindowsLocalServer(bundleDirectory: bundle, token: 'bundled-test-token', port: await _freePort());
      addTearDown(manager.stop);
      await manager.start();
      final client = http.Client();
      addTearDown(client.close);
      expect((await client.get(Uri.parse('${manager.serverUrl}/providers'))).statusCode, 401);
      final providers = await client.get(Uri.parse('${manager.serverUrl}/providers'), headers: {'Authorization': 'Bearer bundled-test-token'});
      expect((jsonDecode(providers.body) as Map)['providers'], isNotEmpty);
      final second = WindowsLocalServer(bundleDirectory: Directory('missing'), token: manager.token, port: manager.port);
      await second.start();
      await second.stop();
      expect((await client.get(Uri.parse('${manager.serverUrl}/health'))).body, 'ok');
      await manager.stop();
      await expectLater(client.get(Uri.parse('${manager.serverUrl}/health')), throwsA(isA<http.ClientException>()));
    },
    skip: !File('${bundle.path}\\chrome-path.txt').existsSync() ? 'Run tool\\bundle_windows_server.ps1 first.' : false,
  );
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
