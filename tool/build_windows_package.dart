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
  final serverReady = File('$root\\build\\windows-server\\chrome-path.txt').existsSync();
  if (!serverReady && !await _runScript(root, 'bundle_windows_server.ps1')) {
    exitCode = 1;
    return;
  }
  if (!await _runScript(root, script)) {
    exitCode = 1;
    return;
  }
  stdout.writeln('Installer ready in $root\\build\\installer');
}

Future<bool> _runScript(String root, String script) async {
  stdout.writeln('> tool\\$script');
  final process = await Process.start('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$root\\tool\\$script'], workingDirectory: root);
  await Future.wait([process.stdout.transform(utf8.decoder).forEach(stdout.write), process.stderr.transform(utf8.decoder).forEach(stderr.write)]);
  final code = await process.exitCode;
  if (code != 0) stderr.writeln('tool\\$script failed with exit code $code.');
  return code == 0;
}
