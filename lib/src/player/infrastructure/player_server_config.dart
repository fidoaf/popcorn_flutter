import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class PlayerServerConfig {
  static const String _definedUrl = String.fromEnvironment('PLAYER_SERVER_URL');
  static String? _localUrl;
  static String? _localToken;

  static String get serverUrl => _localUrl ?? (_definedUrl.isEmpty ? 'https://popcorn-flutter.onrender.com' : _definedUrl);
  static String get providerOverrideUrl => _localUrl ?? _definedUrl;

  /// `true` when the build was launched with `--dart-define=PLAYER_SERVER_URL`,
  /// i.e. it targets an externally started server (the "local server" launch configs).
  static bool get usesDefinedServer => _definedUrl.isNotEmpty;

  static void useLocalServer({required String url, required String token}) {
    _localUrl = url;
    _localToken = token;
  }

  static void useHostedServer() {
    _localUrl = null;
    _localToken = null;
  }

  static String get token {
    if (_localToken != null) return _localToken!;
    const definedToken = String.fromEnvironment('PLAYER_SERVER_TOKEN');
    if (definedToken.isNotEmpty) return definedToken;
    return dotenv.isInitialized ? dotenv.env['playerServer.token'] ?? '' : '';
  }
}
