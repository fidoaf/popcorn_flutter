import 'media_request.dart';
import 'provider_capabilities.dart';

final class RedirectMediaProvider implements EmbedPageProvider {
  RedirectMediaProvider({
    required this.id,
    required this.label,
    required String host,
    String scheme = 'https',
    this.path = '',
    Map<String, String> parameters = const {},
  }) : parameters = Map.unmodifiable(parameters) {
    if (host.isEmpty || !path.startsWith('/') && path.isNotEmpty) {
      throw ArgumentError(
        'Provider $label requires a host and an absolute path',
      );
    }
    if (path.startsWith('//')) {
      throw ArgumentError('Provider $label path must be an absolute path');
    }
    final baseUri = Uri.parse('$scheme://$host');
    if (baseUri.scheme != 'http' && baseUri.scheme != 'https') {
      throw ArgumentError('Provider $label must use HTTP or HTTPS');
    }
    if (baseUri.host.isEmpty) {
      throw ArgumentError(
        'Provider $label requires a host and an absolute path',
      );
    }
    origin = baseUri.origin;
  }

  @override
  final String id;

  @override
  final String label;

  late final String origin;
  final String path;
  final Map<String, String> parameters;

  @override
  Uri embedUrl(MediaRequest media) {
    final values = <String, String>{
      'id': media.id,
      'type': media.type,
      'season': media.type == 'tv' ? media.season : '',
      'episode': media.type == 'tv' ? media.episode : '',
      'language': media.lang.isEmpty ? 'en' : media.lang,
      'subtitles': media.sub.isEmpty ? '1' : media.sub,
    };
    final expandedPath = _substitute(path, values, encodeValues: true);
    final normalizedPath =
        '/${expandedPath.split('/').where((segment) => segment.isNotEmpty).join('/')}';
    var url = Uri.parse('$origin$normalizedPath');
    final resolvedParameters = <String, String>{};
    for (final entry in parameters.entries) {
      final value = _substitute(entry.value, values);
      if (value.isEmpty &&
          RegExp(r'\{(?:season|episode)\}').hasMatch(entry.value)) {
        continue;
      }
      resolvedParameters[_substitute(entry.key, values)] = value;
    }
    if (resolvedParameters.isNotEmpty) {
      url = url.replace(queryParameters: resolvedParameters);
    }
    return url;
  }

  static String _substitute(
    String template,
    Map<String, String> values, {
    bool encodeValues = false,
  }) => template.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
    final placeholder = match.group(0)!;
    final key = match.group(1)!;
    final value = values[key];
    if (value == null) {
      throw FormatException('Unsupported provider placeholder: $placeholder');
    }
    return encodeValues ? Uri.encodeComponent(value) : value;
  });
}
