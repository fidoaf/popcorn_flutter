import 'dart:convert';
import 'dart:io';

/// Builds a local Windows installer: `dart run tool/build_windows_package.dart msix|inno`.
Future<void> main(List<String> args) async {
  const scripts = {'msix': 'build_windows_msix.ps1', 'inno': 'build_windows_installer.ps1'};
  final script = args.isEmpty ? null : scripts[args.first];
  if (script == null) {
    stderr.writeln('Usage: dart run tool/build_windows_package.dart <${scripts.keys.join('|')}>');
    exitCode = 64;
    return;
  }
  if (!Platform.isWindows) {
    stderr.writeln('Windows installers can only be built on Windows.');
    exitCode = 1;
    return;
  }

  final root = File.fromUri(Platform.script).parent.parent.path;
  final environment = _environmentWithFlutterOnPath();
  if (environment == null) {
    stderr.writeln('flutter.bat was not found. Run this with the Flutter SDK Dart executable or add Flutter to PATH.');
    exitCode = 1;
    return;
  }
  if (!await _runScript(root, script, environment)) {
    exitCode = 1;
    return;
  }
  stdout.writeln('Installer ready in $root\\build\\installer');
}

/// VS Code launches this with the configured SDK's dart.exe without adding Flutter to PATH,
/// but the packaging scripts call flutter.bat and dart.bat.
Map<String, String>? _environmentWithFlutterOnPath() {
  final environment = Map<String, String>.of(Platform.environment);
  final pathKey = environment.keys.firstWhere((key) => key.toUpperCase() == 'PATH', orElse: () => 'PATH');
  // dart.exe lives in <flutter>\bin\cache\dart-sdk\bin.
  final flutterBin = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  if (File('${flutterBin.path}\\flutter.bat').existsSync()) {
    environment[pathKey] = '${flutterBin.path};${environment[pathKey] ?? ''}';
    return environment;
  }
  final onPath = (environment[pathKey] ?? '').split(';').any((dir) => dir.isNotEmpty && File('$dir\\flutter.bat').existsSync());
  return onPath ? environment : null;
}

Future<bool> _runScript(String root, String script, Map<String, String> environment) async {
  stdout.writeln('> tool\\$script');
  final process = await Process.start(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$root\\tool\\$script'],
    workingDirectory: root,
    environment: environment,
    includeParentEnvironment: false,
  );
  await Future.wait([process.stdout.transform(utf8.decoder).forEach(stdout.write), process.stderr.transform(utf8.decoder).forEach(stderr.write)]);
  final code = await process.exitCode;
  if (code != 0) stderr.writeln('tool\\$script failed with exit code $code.');
  return code == 0;
}
