final class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.country = '',
    this.languages = const [],
    this.tags = const [],
    this.codec = '',
    this.bitrate = 0,
  });

  final String id;
  final String name;
  final Uri streamUrl;
  final Uri? logoUrl;
  final String country;
  final List<String> languages;
  final List<String> tags;
  final String codec;
  final int bitrate;

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final url = httpUrl(json['url']);
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty || url == null) {
      throw const FormatException('Invalid radio station');
    }
    return RadioStation(
      id: id,
      name: name.trim(),
      streamUrl: url,
      logoUrl: httpUrl(json['logo']),
      country: json['country'] is String ? json['country'] as String : '',
      languages: _strings(json['languages']),
      tags: _strings(json['tags']),
      codec: json['codec'] is String ? json['codec'] as String : '',
      bitrate: json['bitrate'] is num ? (json['bitrate'] as num).toInt() : 0,
    );
  }

  static Uri? httpUrl(Object? value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri != null && {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty ? uri : null;
  }

  static List<String> _strings(Object? value) => value is List ? List.unmodifiable(value.whereType<String>()) : const [];
}
