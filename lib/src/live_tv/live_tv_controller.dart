import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/live_tv/live_tv_channel.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_country.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_programme.dart';
import 'package:popcorn_flutter/src/player/infrastructure/player_server_config.dart';

class LiveTvController extends ChangeNotifier {
  LiveTvController({Uri? endpoint, http.Client? client, String? serverToken})
    : _endpoint = endpoint ?? Uri.parse(PlayerServerConfig.serverUrl).replace(path: '/live-tv'),
      _serverToken = serverToken ?? PlayerServerConfig.token,
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri _endpoint;
  final String _serverToken;
  final http.Client _client;
  final bool _ownsClient;
  int _loadGeneration = 0;
  bool _disposed = false;
  bool _isLoading = false;
  bool _hasError = false;
  List<LiveTvChannel> _channels = const [];
  List<LiveTvCountry> _countries = const [];
  String? _selectedCountry;
  String _query = '';

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<LiveTvChannel> get channels => _channels;
  List<LiveTvCountry> get countries => _countries;
  String? get selectedCountry => _selectedCountry;

  Future<void> search(String query) async {
    _query = query.trim();
    await load();
  }

  Future<void> selectCountry(String? country) async {
    if (_disposed || country == _selectedCountry) return;
    _selectedCountry = country;
    await load();
  }

  Future<List<LiveTvProgramme>> loadProgrammes(String channelId) async {
    final uri = _endpoint.replace(path: '${_endpoint.path}/epg', queryParameters: {'channel': channelId});
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', if (_serverToken.isNotEmpty) 'Authorization': 'Bearer $_serverToken'},
    ).timeout(const Duration(seconds: 50));
    if (response.statusCode != 200) throw http.ClientException('Live TV EPG request failed (${response.statusCode})', uri);
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic> || payload['programmes'] is! List) throw const FormatException('Invalid live TV EPG response');
    return (payload['programmes'] as List).map((entry) {
      if (entry is! Map<String, dynamic>) throw const FormatException('Invalid live TV programme');
      return LiveTvProgramme.fromJson(entry);
    }).toList(growable: false);
  }

  Future<void> load({String? channelId}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final uri = _endpoint.replace(queryParameters: {
        ..._endpoint.queryParameters,
        if (channelId != null) 'channel': channelId,
        if (channelId == null && _selectedCountry != null) 'country': _selectedCountry!,
        if (channelId == null && _query.isNotEmpty) 'q': _query,
      });
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json', if (_serverToken.isNotEmpty) 'Authorization': 'Bearer $_serverToken'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw http.ClientException('Live TV catalogue request failed (${response.statusCode})', uri);
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> || payload['channels'] is! List) {
        throw const FormatException('Invalid live TV catalogue response');
      }
      final channels = (payload['channels'] as List)
          .map((entry) {
            if (entry is! Map<String, dynamic>) throw const FormatException('Invalid live TV channel entry');
            return LiveTvChannel.fromJson(entry);
          })
          .toList(growable: false);
      final rawCountries = payload['countries'];
      if (rawCountries != null && rawCountries is! List) throw const FormatException('Invalid live TV countries');
      final countries = (rawCountries as List? ?? const []).map((entry) {
        if (entry is! Map<String, dynamic>) throw const FormatException('Invalid live TV country');
        return LiveTvCountry.fromJson(entry);
      }).toList(growable: false);
      if (_disposed || generation != _loadGeneration) return;
      _channels = List.unmodifiable(channels);
      _countries = List.unmodifiable(countries);
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      debugPrint('Unable to load live TV catalogue: $error');
      _channels = const [];
      _hasError = true;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
