import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/player/domain/media_source.dart';

Future<MediaSource> createPlayerServerSession(MediaSource source, {http.Client? client}) async {
  final ownedClient = client == null;
  final sessionClient = client ?? http.Client();
  try {
    final endpoint = source.url.resolve('/session');
    final response = await sessionClient.get(endpoint, headers: source.headers).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Player authorization failed: HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    final session = decoded is Map<String, dynamic> ? decoded['session'] : null;
    if (session is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(session)) {
      throw const FormatException('Player server returned an invalid playback session.');
    }
    return MediaSource(
      url: source.url.replace(queryParameters: {...source.url.queryParameters, 'session': session}),
      method: source.method,
      headers: Map.fromEntries(source.headers.entries.where((entry) => entry.key.toLowerCase() != 'authorization')),
      cookies: source.cookies,
      body: source.body,
      data: source.data,
      sandbox: source.sandbox,
    );
  } finally {
    if (ownedClient) sessionClient.close();
  }
}
