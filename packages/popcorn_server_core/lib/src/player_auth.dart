import 'dart:math';

Set<String> parseApiTokens(String? raw) => {
  for (final token in (raw ?? '').split(','))
    if (token.trim().isNotEmpty) token.trim(),
};

final class PlayerAuth {
  PlayerAuth(
    Set<String> apiTokens, {
    DateTime Function()? clock,
    this.sessionTtl = const Duration(minutes: 30),
    this.maxSessions = 10000,
    String Function()? sessionIdGenerator,
  }) : _apiTokens = Set.unmodifiable(apiTokens),
       _clock = clock ?? DateTime.now,
       _sessionIdGenerator = sessionIdGenerator ?? _generateSessionId;

  static const _publicPaths = {'/health', '/favicon.ico'};
  static final _bearerPattern = RegExp(
    r'^Bearer\s+(.+)$',
    caseSensitive: false,
  );

  final Set<String> _apiTokens;
  final DateTime Function() _clock;
  final String Function() _sessionIdGenerator;
  final Duration sessionTtl;
  final int maxSessions;
  final Map<String, DateTime> _sessions = {};

  bool get enabled => _apiTokens.isNotEmpty;
  int get sessionCount => _sessions.length;

  static String? extractBearerToken(String? authorizationHeader) {
    final match = _bearerPattern.firstMatch(authorizationHeader ?? '');
    return match?.group(1)?.trim();
  }

  bool hasBearer(String? token) =>
      !enabled || (token != null && _apiTokens.contains(token));

  bool authorize({
    required String path,
    String? bearerToken,
    String? sessionId,
  }) {
    if (_publicPaths.contains(path)) return true;
    if (path == '/session' || hasBearer(bearerToken)) {
      return hasBearer(bearerToken);
    }
    if (!enabled) return true;
    if (sessionId == null) return false;
    final expiresAt = _sessions[sessionId];
    if (expiresAt == null) return false;
    final now = _clock();
    if (!expiresAt.isAfter(now)) {
      _sessions.remove(sessionId);
      return false;
    }
    _sessions[sessionId] = now.add(sessionTtl);
    return true;
  }

  String createSession() {
    final now = _clock();
    _sessions.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
    if (_sessions.length >= maxSessions) {
      throw const PlayerAuthException(
        'Playback session capacity reached',
        statusCode: 503,
      );
    }
    final id = _sessionIdGenerator();
    _sessions[id] = now.add(sessionTtl);
    return id;
  }

  String? pageSession({String? sessionId}) {
    final expiresAt = sessionId == null ? null : _sessions[sessionId];
    if (expiresAt != null && expiresAt.isAfter(_clock())) return sessionId;
    return enabled ? createSession() : null;
  }

  static String _generateSessionId() {
    final random = Random.secure();
    return List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final class PlayerAuthException implements Exception {
  const PlayerAuthException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
