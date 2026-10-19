import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/live_tv/live_tv_country.dart';
import 'package:popcorn_flutter/src/player/infrastructure/player_server_config.dart';
import 'package:popcorn_flutter/src/radio/radio_station.dart';

class RadioController extends ChangeNotifier {
  RadioController({Uri? endpoint, http.Client? client, String? serverToken})
    : _endpoint = endpoint ?? Uri.parse(PlayerServerConfig.serverUrl).replace(path: '/radio'),
      _client = client ?? http.Client(),
      _ownsClient = client == null,
      _serverToken = serverToken ?? PlayerServerConfig.token;

  final Uri _endpoint;
  final http.Client _client;
  final bool _ownsClient;
  final String _serverToken;
  bool _disposed = false;
  int _generation = 0;
  bool _isLoading = false;
  bool _hasError = false;
  List<RadioStation> _stations = const [];
  List<LiveTvCountry> _countries = const [];
  String? _selectedCountry;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<RadioStation> get stations => _stations;
  List<LiveTvCountry> get countries => _countries;
  String? get selectedCountry => _selectedCountry;

  Future<void> selectCountry(String? country) async {
    if (_disposed || country == _selectedCountry) return;
    _selectedCountry = country;
    await load();
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json', if (_serverToken.isNotEmpty) 'Authorization': 'Bearer $_serverToken'})
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) throw http.ClientException('Radio request failed (${response.statusCode})', uri);
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) throw const FormatException('Invalid radio response');
    return payload;
  }

  Future<void> load({String? stationId}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      final payload = await _get(
        _endpoint.replace(
          queryParameters: {
            if (stationId != null) 'station': stationId,
            if (stationId == null && _selectedCountry != null) 'country': _selectedCountry!,
          },
        ),
      );
      final entries = payload['stations'];
      if (entries is! List) throw const FormatException('Invalid radio catalogue');
      final stations = entries
          .map((entry) {
            if (entry is! Map<String, dynamic>) throw const FormatException('Invalid radio station entry');
            return RadioStation.fromJson(entry);
          })
          .toList(growable: false);
      final rawCountries = payload['countries'];
      if (rawCountries != null && rawCountries is! List) throw const FormatException('Invalid radio countries');
      final countries = (rawCountries as List? ?? const [])
          .map((entry) {
            if (entry is! Map<String, dynamic>) throw const FormatException('Invalid radio country');
            return LiveTvCountry.fromJson(entry);
          })
          .toList(growable: false);
      if (_disposed || generation != _generation) return;
      _stations = List.unmodifiable(stations);
      if (stationId == null) _countries = List.unmodifiable(countries);
    } catch (error) {
      if (_disposed || generation != _generation) return;
      debugPrint('Unable to load radio stations: $error');
      _stations = const [];
      _hasError = true;
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Uri> startPlayback(String id) async {
    final payload = await _get(_endpoint.replace(path: '${_endpoint.path}/play', queryParameters: {'station': id}));
    final url = RadioStation.httpUrl(payload['url']);
    if (url == null) throw const FormatException('Invalid radio playback URL');
    return url;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
