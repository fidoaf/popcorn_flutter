import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('parses comma-separated tokens and extracts a bearer token', () {
    expect(parseApiTokens(' first, ,second '), {'first', 'second'});
    expect(
      PlayerAuth.extractBearerToken('bEaReR  example-token  '),
      'example-token',
    );
    expect(PlayerAuth.extractBearerToken('Basic example-token'), isNull);
  });

  test(
    'authorizes public paths, bearer tokens, and session-only player requests',
    () {
      final auth = PlayerAuth({
        'api-token',
      }, sessionIdGenerator: () => 'session');
      final session = auth.createSession();

      expect(auth.authorize(path: '/health'), isTrue);
      expect(
        auth.authorize(path: '/providers', bearerToken: 'api-token'),
        isTrue,
      );
      expect(
        auth.authorize(path: '/providers', bearerToken: 'wrong-token'),
        isFalse,
      );
      expect(auth.authorize(path: '/player', sessionId: session), isTrue);
      expect(auth.authorize(path: '/session', sessionId: session), isFalse);
    },
  );

  test('session authorization renews on use and expires after inactivity', () {
    var now = DateTime.utc(2026);
    final auth = PlayerAuth(
      {'api-token'},
      clock: () => now,
      sessionTtl: const Duration(seconds: 10),
      sessionIdGenerator: () => 'session',
    );
    final session = auth.createSession();

    now = now.add(const Duration(seconds: 9));
    expect(auth.authorize(path: '/player', sessionId: session), isTrue);
    now = now.add(const Duration(seconds: 9));
    expect(auth.authorize(path: '/player', sessionId: session), isTrue);
    now = now.add(const Duration(seconds: 10));
    expect(auth.authorize(path: '/player', sessionId: session), isFalse);
    expect(auth.sessionCount, 0);
  });

  test('page sessions are reused, created only when auth is enabled, and capacity is enforced', () {
    final auth = PlayerAuth(
      {'api-token'},
      maxSessions: 1,
      sessionIdGenerator: () => 'session',
    );
    final session = auth.pageSession();
    expect(auth.pageSession(sessionId: session), session);
    expect(
      () => auth.createSession(),
      throwsA(
        isA<PlayerAuthException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(PlayerAuth({}).pageSession(), isNull);
    expect(PlayerAuth({}).authorize(path: '/providers'), isTrue);
  });
}
