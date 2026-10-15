import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class PlayerServerConfig {
  static String get token {
    const definedToken = String.fromEnvironment('PLAYER_SERVER_TOKEN');
    if (definedToken.isNotEmpty) return definedToken;
    return dotenv.isInitialized ? dotenv.env['playerServer.token'] ?? '' : '';
  }
}
