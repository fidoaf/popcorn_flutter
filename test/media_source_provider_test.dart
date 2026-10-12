import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_provider_factory.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

void main() {
  const media = MediaItem(id: 42, title: 'Movie', overview: '');
  Map<String, dynamic> config() => {
    'initialProvider': 'Render',
    'providers': [
      {
        'name': 'Render',
        'host': 'popcorn-flutter.onrender.com',
        'path': '/player',
        'parameters': {'id': '{id}', 'type': '{type}', 'season': '{season}', 'episode': '{episode}'},
      },
      {'name': 'External', 'host': 'external.example', 'path': '/embed/{type}/{id}'},
    ],
  };

  test('normal playback keeps the production player origin', () {
    final provider = MediaSourceProviderFactory.createFromMap(config(), playerServerUrl: '');
    expect(provider.resolve(media, MediaType.movie).url.origin, 'https://popcorn-flutter.onrender.com');
  });

  test('local override preserves movie and episode parameters without changing external providers', () {
    final input = config();
    final provider = MediaSourceProviderFactory.createFromMap(input, playerServerUrl: 'http://localhost:3001');
    final movie = provider.resolve(media, MediaType.movie).url;
    expect(movie.origin, 'http://localhost:3001');
    expect(movie.path, '/player');
    expect(movie.queryParameters['id'], '42');
    final episode = provider.resolve(media, MediaType.tv, season: 2, episode: 3).url;
    expect(episode.queryParameters['season'], '2');
    expect(episode.queryParameters['episode'], '3');
    expect(provider.providers.last.resolve(media, MediaType.movie).url.origin, 'https://external.example');
    expect((input['providers'] as List).first['host'], 'popcorn-flutter.onrender.com');
  });

  test('override without a port clears a configured port', () {
    final input = config();
    (input['providers'] as List).first['port'] = 3001;
    final provider = MediaSourceProviderFactory.createFromMap(input, playerServerUrl: 'https://player.example');
    expect(provider.resolve(media, MediaType.movie).url.origin, 'https://player.example');
  });

  test('player override rejects paths and non-HTTP origins', () {
    for (final url in ['localhost:3001', 'ftp://localhost:3001', 'http://localhost:3001/player', 'http://localhost:3001?token=test']) {
      expect(() => MediaSourceProviderFactory.createFromMap(config(), playerServerUrl: url), throwsFormatException);
    }
  });
}
