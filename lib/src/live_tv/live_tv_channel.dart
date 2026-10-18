final class LiveTvChannel {
  const LiveTvChannel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.country = '',
    this.feed = '',
    this.network = '',
    this.website,
    this.languages = const [],
    this.categories = const [],
    this.logoUrl,
    this.logoFormat,
    this.headers = const {},
  });

  final String id;
  final String name;
  final Uri streamUrl;
  final String country;
  final String feed;
  final String network;
  final Uri? website;
  final List<String> languages;
  final List<String> categories;
  final Uri? logoUrl;
  final String? logoFormat;
  bool get hasSvgLogo => logoFormat?.toUpperCase() == 'SVG' || (logoUrl?.path.toLowerCase().endsWith('.svg') ?? false);
  final Map<String, String> headers;

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
      feed: json['feed'] is String ? json['feed'] as String : '',
      network: json['network'] is String ? json['network'] as String : '',
      website: json['website'] is String ? Uri.tryParse(json['website'] as String) : null,
      languages: _stringList(json['languages']),
      categories: _stringList(json['categories']),
      logoUrl: logoUrl != null && {'http', 'https'}.contains(logoUrl.scheme) ? logoUrl : null,
      logoFormat: json['logoFormat'] is String ? json['logoFormat'] as String : null,
      headers: Map.unmodifiable(headers),
    );
  }

  static List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList(growable: false) : const [];
}
