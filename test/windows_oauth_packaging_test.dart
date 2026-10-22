import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both Windows installers register the scheme used by Google OAuth', () {
    final auth = File('lib\\src\\auth\\domain\\auth_controller.dart').readAsStringSync();
    final redirect = Uri.parse(RegExp(r"_nativeRedirect = '([^']+)'").firstMatch(auth)!.group(1)!);
    expect(redirect.host, 'login-callback');
    expect(File('android\\app\\src\\main\\AndroidManifest.xml').readAsStringSync(), contains('android:scheme="${redirect.scheme}"'));
    expect(File('macos\\Runner\\Info.plist').readAsStringSync(), contains('<string>${redirect.scheme}</string>'));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('protocol_activation: ${redirect.scheme}'));
    expect(pubspec, contains('app_links: ^7.2.1'));

    final installer = File('tool\\windows_installer.iss').readAsStringSync();
    final entries = installer.split('\n').where((line) => line.startsWith('Root:')).toList();
    expect(entries, hasLength(4));
    for (final entry in entries) {
      expect(entry, startsWith('Root: HKCU;'));
      expect(entry, contains('Software\\Classes\\${redirect.scheme}'));
    }
    expect(entries, contains(contains('ValueName: "URL Protocol"; ValueData: ""')));
    expect(entries.last, contains(r'ValueData: """{app}\popcorn_flutter.exe"" ""%1"""'));
    expect(installer, contains('ChangesAssociations=yes'));
  });

  test('Windows forwards callback to existing instance before creating Flutter engine', () {
    final runner = File('windows\\runner\\main.cpp').readAsStringSync();
    final forward = runner.indexOf('if (SendAppLinkToInstance())');
    expect(forward, greaterThan(0));
    expect(forward, lessThan(runner.indexOf('flutter::DartProject project')));
    expect(runner.substring(forward, runner.indexOf('// Attach to console')), contains('return EXIT_SUCCESS;'));
    expect(runner, contains('#include "app_links/app_links_plugin_c_api.h"'));
  });
}
