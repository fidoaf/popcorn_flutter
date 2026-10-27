import 'dart:convert';

import 'country_metadata.dart';
import 'provider_http_client.dart';

typedef RadioServerDiscovery = Future<List<String>> Function();

final class RadioCatalog {
  RadioCatalog({
    required ProviderHttpClient httpClient,
    RadioServerDiscovery? discoverServers,
    CountryNameResolver countryNames = const CommonCountryNameResolver(),
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 8),
  }) : _httpClient = httpClient,
       _discoverServers = discoverServers ?? _defaultServers,
       _countryNames = countryNames,
       _clock = clock ?? DateTime.now;

  static const _cacheTtl = Duration(hours: 1);
  static const _agent = 'PopcornFlutter/1.0 (Radio Browser client)';
  static final _stationIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final ProviderHttpClient _httpClient;
  final RadioServerDiscovery _discoverServers;
  final CountryNameResolver _countryNames;
  final DateTime Function() _clock;
  final Duration timeout;
  List<String>? _servers;
  DateTime _serversExpireAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<List<String>>? _discovery;
  final Map<String, _CachedRadioStations> _catalogues = {};
  final Map<String, Future<List<Map<String, Object?>>>> _inFlight = {};
  List<Map<String, Object?>>? _countries;
  DateTime _countriesExpireAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<List<Map<String, Object?>>>? _countriesInFlight;

  static Future<List<String>> _defaultServers() async => const [
    'de1.api.radio-browser.info',
    'de2.api.radio-browser.info',
    'nl1.api.radio-browser.info',
  ];

  Future<List<String>> _getServers() async {
    if (_servers != null && _serversExpireAt.isAfter(_clock())) {
      return _servers!;
    }
    if (_discovery != null) {
      return _discovery!;
    }
    _discovery = () async {
      final servers = (await _discoverServers())
          .where(
            (host) => RegExp(
              r'^[a-z0-9-]+\.api\.radio-browser\.info$',
              caseSensitive: false,
            ).hasMatch(host),
          )
          .toSet()
          .toList();
      if (servers.isEmpty) {
        throw StateError('Radio Browser discovery returned no servers');
      }
      _servers = servers.take(3).toList();
      _serversExpireAt = _clock().add(_cacheTtl);
      return _servers!;
    }().whenComplete(() => _discovery = null);
    return _discovery!;
  }

  Future<Object?> _request(String path, bool Function(Object?) validate) async {
    final errors = <Object>[];
    for (final host in await _getServers()) {
      try {
        final response = await _httpClient.get(
          Uri.parse('https://$host$path'),
          headers: const {'Accept': 'application/json', 'User-Agent': _agent},
          timeout: timeout,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ProviderHttpException('HTTP ${response.statusCode}');
        }
        final payload = jsonDecode(response.body);
        if (!validate(payload)) {
          throw const FormatException('Invalid Radio Browser response');
        }
        return payload;
      } on Object catch (error) {
        errors.add(error);
      }
    }
    _serversExpireAt = DateTime.fromMillisecondsSinceEpoch(0);
    throw RadioCatalogException('Radio Browser is unavailable', errors: errors);
  }

  Future<List<Map<String, Object?>>> _getCountries() async {
    if (_countries != null && _countriesExpireAt.isAfter(_clock())) {
      return _countries!;
    }
    _countriesInFlight ??= () async {
      final entries = await _request(
        '/json/countrycodes?hidebroken=true',
        (value) => value is List,
      );
      final codes = <String>{};
      for (final entry in (entries as List).whereType<Map>()) {
        final code = entry['name'];
        final count = entry['stationcount'];
        if (code is String &&
            RegExp(r'^[A-Z]{2}$').hasMatch(code) &&
            count is num &&
            count > 0) {
          codes.add(code);
        }
      }
      _countries =
          codes
              .map((code) => countryMetadata(code, _countryNames).toJson())
              .toList()
            ..sort(
              (left, right) => '${left['name']}'.compareTo('${right['name']}'),
            );
      _countriesExpireAt = _clock().add(_cacheTtl);
      return _countries!;
    }().whenComplete(() => _countriesInFlight = null);
    return _countriesInFlight!;
  }

  Future<Map<String, Object?>> getCatalogue({
    String country = '',
    String query = '',
  }) async {
    if (country.isNotEmpty && !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const RadioCatalogException(
        'Invalid radio country',
        statusCode: 400,
        code: 'invalid_radio_country',
      );
    }
    final search = query.trim();
    final key = '${country.toLowerCase()}:${search.toLowerCase()}';
    final cached = _catalogues[key];
    if (cached != null && cached.expiresAt.isAfter(_clock())) {
      return {'stations': cached.stations, 'countries': await _getCountries()};
    }
    final stationsFuture = _inFlight.putIfAbsent(
      key,
      () => _loadStations(country: country, search: search, cacheKey: key),
    );
    try {
      final stations = await stationsFuture;
      return {'stations': stations, 'countries': await _getCountries()};
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<Map<String, Object?>>> _loadStations({
    required String country,
    required String search,
    required String cacheKey,
  }) async {
    final parameters = <String, String>{
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '60',
      if (country.isNotEmpty) 'countrycode': country,
      if (search.isNotEmpty) 'name': search,
    };
    final queryString = Uri(queryParameters: parameters).query;
    final entries =
        await _request(
              '/json/stations/search?$queryString',
              (value) => value is List,
            )
            as List;
    final stations = <String, Map<String, Object?>>{};
    for (final entry in entries.whereType<Map>()) {
      final station = _normalizeStation(entry);
      if (station == null) continue;
      if (country.isNotEmpty && station['countryCode'] != country) continue;
      stations.putIfAbsent(station['id']! as String, () => station);
    }
    final result = stations.values.take(60).toList();
    _catalogues.remove(cacheKey);
    _catalogues[cacheKey] = _CachedRadioStations(
      result,
      _clock().add(_cacheTtl),
    );
    if (_catalogues.length > 32) _catalogues.remove(_catalogues.keys.first);
    return result;
  }

  Future<Map<String, Object?>?> getStation(String id) async {
    _validateId(id);
    final entries =
        await _request('/json/stations/byuuid/$id', (value) => value is List)
            as List;
    for (final entry in entries.whereType<Map>()) {
      if (entry['stationuuid'] == id) return _normalizeStation(entry);
    }
    return null;
  }

  Future<Map<String, String>> startPlayback(String id) async {
    _validateId(id);
    final payload =
        await _request(
              '/json/url/$id',
              (value) =>
                  value is Map &&
                  value['ok'] == true &&
                  value['stationuuid'] == id &&
                  _httpUrl(value['url']) != null,
            )
            as Map;
    return {'url': _httpUrl(payload['url'])!};
  }

  void _validateId(String id) {
    if (!_stationIdPattern.hasMatch(id)) {
      throw const RadioCatalogException(
        'Invalid radio station ID',
        statusCode: 400,
        code: 'invalid_radio_station',
      );
    }
  }

  Map<String, Object?>? _normalizeStation(Map station) {
    final id = station['stationuuid'];
    final name = station['name'];
    if (id is! String ||
        !_stationIdPattern.hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty) {
      return null;
    }
    final url = _httpUrl(station['url_resolved']) ?? _httpUrl(station['url']);
    if (url == null || station['lastcheckok'] != 1) return null;
    final languages = station['language'];
    final tags = station['tags'];
    final bitrate = station['bitrate'];
    return {
      'id': id,
      'name': name.trim(),
      'url': url,
      'logo': _httpUrl(station['favicon']),
      'website': _httpUrl(station['homepage']),
      'country': station['country'] is String ? station['country'] : '',
      'countryCode': station['countrycode'] is String
          ? station['countrycode']
          : '',
      'languages': languages is String ? _splitValues(languages) : <String>[],
      'tags': tags is String ? _splitValues(tags) : <String>[],
      'codec': station['codec'] is String ? station['codec'] : '',
      'bitrate': bitrate is num && bitrate.isFinite && bitrate > 0
          ? bitrate
          : 0,
    };
  }

  List<String> _splitValues(String value) => [
    for (final part in value.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  String? _httpUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.path.isEmpty
        ? uri.replace(path: '/').toString()
        : uri.toString();
  }
}

final class RadioCatalogException implements Exception {
  const RadioCatalogException(
    this.message, {
    this.statusCode = 502,
    this.code,
    this.errors = const [],
  });

  final String message;
  final int statusCode;
  final String? code;
  final List<Object> errors;

  @override
  String toString() => message;
}

final class _CachedRadioStations {
  const _CachedRadioStations(this.stations, this.expiresAt);

  final List<Map<String, Object?>> stations;
  final DateTime expiresAt;
}
