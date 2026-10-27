import 'dart:convert';

import 'media_request.dart';
import 'provider_http_client.dart';

final class IntroDbClient {
  IntroDbClient({
    required ProviderHttpClient httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient;

  final ProviderHttpClient _httpClient;
  final Duration timeout;

  Future<Map<String, dynamic>> fetch(Map<String, String> parameters) async {
    final id = parameters['id'] ?? '';
    final type = parameters['type'];
    final duration = parameters['duration_ms'] ?? '';
    if (!RegExp(r'^(tt\d+|[1-9]\d*)$').hasMatch(id) ||
        (type != 'movie' && type != 'tv') ||
        !RegExp(r'^[1-9]\d*$').hasMatch(duration) ||
        int.tryParse(duration) == null ||
        int.parse(duration) > 9007199254740991) {
      throw const InvalidMediaRequest('Invalid IntroDB media or duration');
    }

    final query = <String, String>{
      id.startsWith('tt') ? 'imdb_id' : 'tmdb_id': id,
      'duration_ms': duration,
    };
    if (type == 'tv') {
      for (final key in ['season', 'episode']) {
        final value = parameters[key] ?? '';
        if (!RegExp(r'^[1-9]\d*$').hasMatch(value)) {
          throw const InvalidMediaRequest('Invalid IntroDB episode');
        }
        query[key] = value;
      }
    }

    final uri = Uri.https('api.theintrodb.org', '/v4/media', query);
    final response = await _httpClient.get(
      uri,
      headers: const {},
      timeout: timeout,
    );
    if (response.statusCode == 404) {
      return {'intro': [], 'credits': []};
    }
    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'IntroDB request failed (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid IntroDB response');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
