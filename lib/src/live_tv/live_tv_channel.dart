import 'dart:ui';

final class LiveTvChannel {
  const LiveTvChannel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.country = '',
    this.countryNames = const {},
    this.feed = '',
    this.network = '',
    this.website,
    this.languages = const [],
    this.categories = const [],
    this.logoUrl,
    this.logoFormat,
    this.headers = const {},
    this.isGeoBlocked = false,
    this.broadcastAreas = const [],
  });

  final String id;
  final String name;
  final Uri streamUrl;
  final String country;
  final Map<String, String> countryNames;
  String localizedCountry(Locale locale) => countryNames[locale.languageCode] ?? country;
  final String feed;
  final String network;
  final Uri? website;
  final List<String> languages;
  final List<String> categories;
  final Uri? logoUrl;
  final String? logoFormat;
  bool get hasSvgLogo => logoFormat?.toUpperCase() == 'SVG' || (logoUrl?.path.toLowerCase().endsWith('.svg') ?? false);
  final Map<String, String> headers;
  final bool isGeoBlocked;
  final List<LiveTvBroadcastArea> broadcastAreas;

  factory LiveTvChannel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rawUrl = json['url'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty || rawUrl is! String) {
      throw const FormatException('Invalid live TV channel');
    }

    final streamUrl = Uri.tryParse(rawUrl);
    if (streamUrl == null || !{'http', 'https'}.contains(streamUrl.scheme) || streamUrl.host.isEmpty) {
      throw const FormatException('Invalid live TV stream URL');
    }

    final rawLogo = json['logo'];
    final logoUrl = rawLogo is String ? Uri.tryParse(rawLogo) : null;
    final rawHeaders = json['headers'];
    final rawCountryNames = json['countryNames'];
    final countryNames = <String, String>{};
    if (rawCountryNames != null) {
      if (rawCountryNames is! Map<String, dynamic>) throw const FormatException('Invalid live TV country names');
      for (final entry in rawCountryNames.entries) {
        final value = entry.value;
        if (value is! String || value.isEmpty) throw const FormatException('Invalid live TV country name');
        countryNames[entry.key] = value;
      }
    }
    final rawAreas = json['broadcastAreas'];
    if (rawAreas != null && rawAreas is! List) throw const FormatException('Invalid live TV broadcast areas');
    final areas = <LiveTvBroadcastArea>[];
    if (rawAreas is List) {
      for (final area in rawAreas) {
        if (area is! Map<String, dynamic>) throw const FormatException('Invalid live TV broadcast area');
        areas.add(LiveTvBroadcastArea.fromJson(area));
      }
    }
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }

    return LiveTvChannel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      country: json['country'] is String ? json['country'] as String : '',
      countryNames: Map.unmodifiable(countryNames),
      feed: json['feed'] is String ? json['feed'] as String : '',
      network: json['network'] is String ? json['network'] as String : '',
      website: json['website'] is String ? Uri.tryParse(json['website'] as String) : null,
      languages: _stringList(json['languages']),
      categories: _stringList(json['categories']),
      logoUrl: logoUrl != null && {'http', 'https'}.contains(logoUrl.scheme) ? logoUrl : null,
      logoFormat: json['logoFormat'] is String ? json['logoFormat'] as String : null,
      headers: Map.unmodifiable(headers),
      isGeoBlocked: json['isGeoBlocked'] == true,
      broadcastAreas: List.unmodifiable(areas),
    );
  }

  static List<String> _stringList(Object? value) => value is List ? value.whereType<String>().toList(growable: false) : const [];
}

final class LiveTvBroadcastArea {
  const LiveTvBroadcastArea({required this.code, required this.name, this.names = const {}});

  final String code;
  final String name;
  final Map<String, String> names;

  String localizedName(Locale locale) => names[locale.languageCode] ?? name;

  factory LiveTvBroadcastArea.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final name = json['name'];
    if (code is! String || code.isEmpty || name is! String || name.isEmpty) {
      throw const FormatException('Invalid live TV broadcast area');
    }
    final rawNames = json['names'];
    final names = <String, String>{};
    if (rawNames != null) {
      if (rawNames is! Map<String, dynamic>) throw const FormatException('Invalid live TV broadcast area names');
      for (final entry in rawNames.entries) {
        final value = entry.value;
        if (value is! String || value.isEmpty) throw const FormatException('Invalid live TV broadcast area name');
        names[entry.key] = value;
      }
    }
    return LiveTvBroadcastArea(code: code, name: name, names: Map.unmodifiable(names));
  }
}
