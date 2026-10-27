import 'dart:convert';

import 'country_metadata.dart';
import 'provider_http_client.dart';

final class LiveTvCatalog {
  LiveTvCatalog({
    required ProviderHttpClient httpClient,
    CountryNameResolver countryNames = const CommonCountryNameResolver(),
    DateTime Function()? clock,
    this.ttl = const Duration(hours: 6),
    this.maxChannels = 60,
    this.timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient,
       _countryNames = countryNames,
       _clock = clock ?? DateTime.now;

  static const _channelsUrl = 'https://iptv-org.github.io/api/channels.json';
  static const _streamsUrl = 'https://iptv-org.github.io/api/streams.json';
  static const _logosUrl = 'https://iptv-org.github.io/api/logos.json';
  static const _areaSources = ['feeds', 'regions', 'subdivisions', 'cities'];

  final ProviderHttpClient _httpClient;
  final CountryNameResolver _countryNames;
  final DateTime Function() _clock;
  final Duration ttl;
  final int maxChannels;
  final Duration timeout;
  List<Map<String, Object?>>? _channels;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<List<Map<String, Object?>>>? _inFlight;

  Future<List<Map<String, Object?>>> getChannels([String country = '']) async {
    final channels = await _getAllChannels();
    return channels.where((channel) => country.isEmpty || channel['country'] == country).take(maxChannels).toList();
  }

  Future<Map<String, Object?>?> getChannel(String id) async {
    for (final channel in await _getAllChannels()) {
      if (channel['id'] == id) return channel;
    }
    return null;
  }

  Future<Map<String, Object?>> getCatalogue({String country = '', String? channelId, String query = ''}) async {
    final allChannels = await _getAllChannels();
    final countries =
        <String>{
            for (final channel in allChannels)
              if (channel['country'] is String) channel['country'] as String,
          }.where((code) => RegExp(r'^[A-Z]{2}$').hasMatch(code)).map((code) => countryMetadata(code, _countryNames).toJson()).toList()
          ..sort((left, right) => '${left['name']}'.compareTo('${right['name']}'));
    final search = query.trim().toLowerCase();
    final channels = allChannels
        .where((channel) => channelId != null ? channel['id'] == channelId : country.isEmpty || channel['country'] == country)
        .where((channel) => search.isEmpty || '${channel['name']}'.toLowerCase().contains(search) || '${channel['id']}'.toLowerCase().contains(search))
        .take(maxChannels)
        .toList();
    return {'channels': channels, 'countries': countries};
  }

  Future<List<Map<String, Object?>>> _getAllChannels() {
    if (_channels != null && _expiresAt.isAfter(_clock())) {
      return Future.value(_channels);
    }
    return _inFlight ??= _loadChannels()
        .then((channels) {
          _channels = channels;
          _expiresAt = _clock().add(ttl);
          return channels;
        })
        .whenComplete(() => _inFlight = null);
  }

  Future<List<Map<String, Object?>>> _loadChannels() async {
    final urls = [_channelsUrl, _streamsUrl, _logosUrl, for (final source in _areaSources) 'https://iptv-org.github.io/api/$source.json'];
    final responses = await Future.wait(urls.map((url) => _getJson(Uri.parse(url))));
    if (responses.any((response) => response is! List)) {
      throw const FormatException('iptv-org returned an invalid catalogue format');
    }
    final channels = responses[0] as List;
    final streams = responses[1] as List;
    final logos = responses[2] as List;
    final areas = _indexBroadcastAreas(responses[3] as List, responses[4] as List, responses[5] as List, responses[6] as List);
    final logosByChannel = _indexLogos(logos);
    final channelById = <String, Map<String, Object?>>{};
    for (final value in channels.whereType<Map>()) {
      final id = value['id'];
      final name = value['name'];
      if (id is! String || name is! String || name.trim().isEmpty) continue;
      final country = value['country'] is String ? value['country'] as String : '';
      channelById[id] = {
        'id': id,
        'name': name.trim(),
        'country': country,
        'countryNames': RegExp(r'^[A-Z]{2}$').hasMatch(country) ? _countryNames.names(country) : <String, String>{},
        'website': _httpUrl(value['website']),
        'network': value['network'] is String ? value['network'] : '',
        'languages': _stringList(value['languages']),
        'categories': _stringList(value['categories']),
      };
    }

    final streamByChannel = <String, Map<String, Object?>>{};
    for (final value in streams.whereType<Map>()) {
      final channelId = value['channel'];
      if (channelId is! String || streamByChannel.containsKey(channelId)) {
        continue;
      }
      final url = _httpUrl(value['url']);
      if (url == null || !channelById.containsKey(channelId)) {
        continue;
      }
      final feed = value['feed'] is String ? value['feed'] as String : '';
      final channelLogos = logosByChannel[channelId];
      final logo = channelLogos?[feed] ?? channelLogos?[''];
      streamByChannel[channelId] = {
        'feed': feed,
        'url': url,
        'headers': _normalizeHeaders(value),
        'isGeoBlocked': value['labels'] is List && (value['labels'] as List).contains('Geo-blocked'),
        'broadcastAreas': areas[channelId]?[feed] ?? const [],
        'logo': logo?['url'],
        'logoFormat': logo?['format'],
      };
    }

    final result = <Map<String, Object?>>[
      for (final entry in streamByChannel.entries) {...channelById[entry.key]!, ...entry.value},
    ]..sort((first, second) => '${first['name']}'.compareTo('${second['name']}'));
    return result;
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await _httpClient.get(uri, headers: const {}, timeout: timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProviderHttpException('iptv-org catalogue request failed (${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  Map<String, Map<String, Map<String, Object?>>> _indexLogos(List logos) {
    final result = <String, Map<String, Map<String, Object?>>>{};
    for (final logo in logos.whereType<Map>()) {
      final channel = logo['channel'];
      final url = _httpUrl(logo['url']);
      if (channel is! String || url == null) continue;
      final feed = logo['feed'] is String ? logo['feed'] as String : '';
      final tags = logo['tags'] is List ? logo['tags'] as List : const [];
      final priority = (logo['in_use'] == true ? 4 : 0) + (tags.contains('horizontal') ? 2 : 0) + (tags.contains('white') ? 1 : 0);
      final channelLogos = result.putIfAbsent(channel, () => {});
      final previous = channelLogos[feed];
      if (previous == null || priority > (previous['priority'] as int)) {
        channelLogos[feed] = {'url': url, 'format': logo['format'] is String ? logo['format'] : null, 'priority': priority};
      }
    }
    return result;
  }

  Map<String, Map<String, List<Map<String, Object?>>>> _indexBroadcastAreas(List feeds, List regions, List subdivisions, List cities) {
    final areaNames = <String, String>{};
    for (final (prefix, entries) in [('r', regions), ('s', subdivisions), ('ct', cities)]) {
      for (final entry in entries.whereType<Map>()) {
        final code = entry['code'];
        final name = entry['name'];
        if (code is String && name is String && name.trim().isNotEmpty) {
          areaNames['$prefix/$code'] = name.trim();
        }
      }
    }
    final result = <String, Map<String, List<Map<String, Object?>>>>{};
    for (final feed in feeds.whereType<Map>()) {
      final channel = feed['channel'];
      final feedId = feed['id'];
      if (channel is! String || feedId is! String) continue;
      final codes = feed['broadcast_area'] is List ? feed['broadcast_area'] as List : const [];
      final entries = <Map<String, Object?>>[];
      final seen = <String>{};
      for (final value in codes) {
        if (value is! String || !RegExp(r'^(c|r|s|ct)/[^/]+$').hasMatch(value) || !seen.add(value)) {
          continue;
        }
        final country = value.startsWith('c/') ? value.substring(2) : '';
        final names = RegExp(r'^[A-Z]{2}$').hasMatch(country) ? _countryNames.names(country) : <String, String>{};
        entries.add({'code': value, 'name': names['en'] ?? areaNames[value] ?? value, 'names': names});
      }
      result.putIfAbsent(channel, () => {})[feedId] = entries;
    }
    return result;
  }

  Map<String, String> _normalizeHeaders(Map stream) => {
    if (stream['http_referrer'] is String && (stream['http_referrer'] as String).trim().isNotEmpty) 'Referer': (stream['http_referrer'] as String).trim(),
    if (stream['user_agent'] is String && (stream['user_agent'] as String).trim().isNotEmpty) 'User-Agent': (stream['user_agent'] as String).trim(),
  };

  List<String> _stringList(Object? value) => value is List ? value.whereType<String>().toList() : <String>[];

  String? _httpUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.path.isEmpty ? uri.replace(path: '/').toString() : uri.toString();
  }
}
