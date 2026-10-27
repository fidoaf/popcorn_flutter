import 'dart:convert';
import 'dart:io';

import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

Future<void> main() async {
  final environment = Platform.environment;
  final port = int.tryParse(environment['PORT'] ?? '') ?? 3001;
  final host = environment['HOST'] ?? '0.0.0.0';
  final rawTokens = _firstNonEmpty(environment['API_TOKENS'], environment['AUTH_TOKEN']);
  final configPath =
      environment['MEDIA_SOURCE_PROVIDERS_PATH'] ?? Platform.script.resolve('../../../assets/config/server_media_source_providers.json').toFilePath();
  final decoded = jsonDecode(await File(configPath).readAsString());
  if (decoded is! Map) throw const FormatException('Media source provider configuration must be an object.');
  final config = Map<String, Object?>.from(decoded);
  final httpClient = DartIoProviderHttpClient();
  final providers = CoreMediaProviderFactory.fromJson(config: config, httpClient: httpClient, postClient: httpClient);
  final server = DartPlayerServer(
    providers: providers,
    apiTokens: parseApiTokens(rawTokens),
    host: host,
    port: port,
    providerHttpClient: httpClient,
    streamingHttpClient: httpClient,
  );

  try {
    final address = await server.start();
    stdout.writeln('Player available at $address/');
    await Future.any([ProcessSignal.sigterm.watch().first, ProcessSignal.sigint.watch().first]);
  } finally {
    await server.stop();
    httpClient.close(force: true);
  }
}

String? _firstNonEmpty(String? first, String? second) => first != null && first.trim().isNotEmpty ? first : second;
