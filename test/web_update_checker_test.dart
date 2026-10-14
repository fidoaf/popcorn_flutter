import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/app/update/web_update_checker.dart';

void main() {
  MockClient serving(String version) => MockClient((_) async => http.Response(jsonEncode({'version': version}), 200));

  test('flags an update on the first check when a cached bundle is older than the deployed one', () async {
    final checker = WebUpdateChecker(client: serving('1.6.4'), runningVersion: '1.6.3');
    addTearDown(checker.dispose);

    await checker.start();

    expect(checker.updateAvailable, isTrue);
  });

  test('stays quiet when the running bundle matches the deployed version', () async {
    final checker = WebUpdateChecker(client: serving('1.6.4'), runningVersion: '1.6.4');
    addTearDown(checker.dispose);

    await checker.start();

    expect(checker.updateAvailable, isFalse);
  });

  test('falls back to the first fetched version as baseline when no version is compiled in', () async {
    final checker = WebUpdateChecker(client: serving('1.6.4'), runningVersion: '');
    addTearDown(checker.dispose);

    await checker.start();

    expect(checker.updateAvailable, isFalse);
  });
}
