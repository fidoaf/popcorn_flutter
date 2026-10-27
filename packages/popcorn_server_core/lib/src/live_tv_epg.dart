import 'dart:collection';
import 'dart:convert';

import 'package:xml/xml_events.dart';

import 'provider_http_client.dart';

final class LiveTvEpg {
  LiveTvEpg({
    required ProviderHttpClient httpClient,
    required ProviderStreamingHttpClient streamingHttpClient,
    DateTime Function()? clock,
    this.directoryTtl = const Duration(hours: 6),
    this.guideTtl = const Duration(minutes: 15),
    this.maxGuideBytes = 256 * 1024 * 1024,
    this.maxCachedGuides = 4,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient,
       _streamingHttpClient = streamingHttpClient,
       _clock = clock ?? DateTime.now;

  static final _guidesUri = Uri.https('iptv-epg.org', '/guides');
  static final _guidePattern = RegExp(r'https://iptv-epg\.org/files/epg-([a-z]{2})\.xml(?=["\s<])');

  final ProviderHttpClient _httpClient;
  final ProviderStreamingHttpClient _streamingHttpClient;
  final DateTime Function() _clock;
  final Duration directoryTtl;
  final Duration guideTtl;
  final Duration timeout;
  final int maxGuideBytes;
  final int maxCachedGuides;

  final Map<String, Uri> _guides = {};
  DateTime _guidesExpireAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<Map<String, Uri>>? _guidesLoad;
  final LinkedHashMap<Uri, _CachedGuide> _guideCache = LinkedHashMap();
  final Map<Uri, Future<_ParsedGuide>> _guideLoads = {};

  Future<List<Map<String, String>>> getProgrammes(Map<String, Object?> channel) async {
    final country = channel['country'];
    if (country is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      return const [];
    }
    final guideUri = (await _loadGuides())[country];
    if (guideUri == null) return const [];
    try {
      final guide = await _loadGuide(guideUri);
      return guide.programmesFor(channel, _clock());
    } on Object {
      _guideCache.remove(guideUri);
      rethrow;
    }
  }

  Future<Map<String, Uri>> _loadGuides() {
    if (_guides.isNotEmpty && _guidesExpireAt.isAfter(_clock())) {
      return Future.value(_guides);
    }
    return _guidesLoad ??= _fetchGuides().whenComplete(() => _guidesLoad = null);
  }

  Future<Map<String, Uri>> _fetchGuides() async {
    final response = await _httpClient.get(_guidesUri, headers: const {}, timeout: const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProviderHttpException('EPG directory request failed (${response.statusCode})');
    }
    final guides = <String, Uri>{};
    for (final match in _guidePattern.allMatches(response.body)) {
      final country = match.group(1)!.toUpperCase();
      guides[country] = Uri.parse(match.group(0)!);
    }
    if (guides.isEmpty) {
      throw const FormatException('Invalid IPTV-EPG guide directory: no country guides found');
    }
    _guides
      ..clear()
      ..addAll(guides);
    _guidesExpireAt = _clock().add(directoryTtl);
    return _guides;
  }

  Future<_ParsedGuide> _loadGuide(Uri uri) async {
    final cached = _guideCache.remove(uri);
    if (cached != null && cached.expiresAt.isAfter(_clock())) {
      _guideCache[uri] = cached;
      return cached.guide;
    }
    if (cached != null) _guideCache.remove(uri);
    final pending = _guideLoads[uri];
    if (pending != null) return pending;
    final future = _fetchGuide(uri);
    _guideLoads[uri] = future;
    try {
      final guide = await future;
      _guideCache[uri] = _CachedGuide(guide, _clock().add(guideTtl));
      while (_guideCache.length > maxCachedGuides) {
        _guideCache.remove(_guideCache.keys.first);
      }
      return guide;
    } finally {
      _guideLoads.remove(uri);
    }
  }

  Future<_ParsedGuide> _fetchGuide(Uri uri) async {
    final response = await _streamingHttpClient.getStream(uri, headers: const {}, timeout: timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.body.drain<void>();
      throw ProviderHttpException('EPG source request failed (${response.statusCode})');
    }
    final parser = _XmlTvParser(_clock());
    final boundedBytes = _boundedBytes(response.body, maxGuideBytes);
    final decodedChunks = _completeEntityReferences(boundedBytes.transform(utf8.decoder));
    final events = decodedChunks.toXmlEvents(validateDocument: true, validateNesting: true);
    try {
      await for (final batch in events) {
        for (final event in batch) {
          parser.add(event);
        }
      }
    } on Object catch (error) {
      if (error is FormatException && error.message.startsWith('Invalid XMLTV guide:')) {
        rethrow;
      }
      throw FormatException('Invalid XMLTV guide: $error');
    }
    return parser.finish();
  }

  Stream<List<int>> _boundedBytes(Stream<List<int>> source, int limit) async* {
    var total = 0;
    await for (final chunk in source) {
      total += chunk.length;
      if (total > limit) throw const FormatException('EPG source exceeds size limit');
      yield chunk;
    }
  }
}

Stream<String> _completeEntityReferences(Stream<String> input) async* {
  var carry = '';
  await for (final chunk in input) {
    carry += chunk;
    final ampersand = carry.lastIndexOf('&');
    final semicolon = carry.lastIndexOf(';');
    final tagStart = carry.lastIndexOf('<');
    if (ampersand > semicolon && ampersand > tagStart) {
      if (ampersand > 0) yield carry.substring(0, ampersand);
      carry = carry.substring(ampersand);
    } else {
      yield carry;
      carry = '';
    }
  }
  if (carry.isNotEmpty) yield carry;
}

final class _CachedGuide {
  const _CachedGuide(this.guide, this.expiresAt);

  final _ParsedGuide guide;
  final DateTime expiresAt;
}

final class _GuideChannel {
  const _GuideChannel(this.id, this.displayNames);

  final String id;
  final List<String> displayNames;
}

final class _XmlTvProgramme {
  const _XmlTvProgramme({required this.channelId, required this.title, required this.description, required this.start, required this.end});

  final String channelId;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  Map<String, String> toJson() => {'title': title, 'description': description, 'start': start.toUtc().toIso8601String(), 'end': end.toUtc().toIso8601String()};
}

final class _ParsedGuide {
  const _ParsedGuide(this.channels, this.programmes);

  final List<_GuideChannel> channels;
  final Map<String, List<_XmlTvProgramme>> programmes;

  List<Map<String, String>> programmesFor(Map<String, Object?> channel, DateTime now) {
    final id = channel['id'];
    if (id is! String) return const [];
    final feed = channel['feed'];
    final feedId = feed is String && feed.isNotEmpty ? '$id@$feed' : null;
    final ids = <String>{};
    if (feedId != null && channels.any((entry) => entry.id == feedId)) {
      ids.add(feedId);
    } else if (channels.any((entry) => entry.id == id)) {
      ids.add(id);
    } else {
      final name = channel['name'];
      if (name is! String || name.isEmpty) return const [];
      final normalized = _normalizedName(name);
      final matches = channels.where((entry) => entry.displayNames.any((displayName) => _normalizedName(displayName) == normalized)).toList();
      if (matches.length == 1) ids.add(matches.single.id);
    }
    final rows = <_XmlTvProgramme>[
      for (final channelId in ids)
        for (final programme in programmes[channelId] ?? const <_XmlTvProgramme>[])
          if (programme.end.isAfter(now)) programme,
    ]..sort((left, right) => left.start.compareTo(right.start));
    return rows.take(100).map((programme) => programme.toJson()).toList();
  }
}

final class _XmlTvParser {
  _XmlTvParser(this.now);

  final DateTime now;
  final List<_GuideChannel> channels = [];
  final Map<String, List<_XmlTvProgramme>> programmes = {};
  _XmlTvEntry? entry;
  int depth = 0;
  int fieldDepth = 0;
  String? field;
  StringBuffer? fieldText;
  bool hasRoot = false;

  void add(XmlEvent event) {
    if (event is XmlDoctypeEvent) {
      throw const FormatException('Invalid XMLTV guide: DOCTYPE is not supported');
    }
    if (event is XmlStartElementEvent) {
      _start(event);
    } else if (event is XmlEndElementEvent) {
      _end(event);
    } else if (event is XmlTextEvent) {
      _append(event.value);
    } else if (event is XmlCDATAEvent) {
      _append(event.value);
    }
  }

  _ParsedGuide finish() {
    if (!hasRoot) throw const FormatException('Invalid XMLTV guide: missing tv element');
    return _ParsedGuide(List.unmodifiable(channels), Map.unmodifiable(programmes));
  }

  void _start(XmlStartElementEvent event) {
    depth++;
    if (depth == 1) {
      if (event.name != 'tv') throw const FormatException('Invalid XMLTV guide: missing tv element');
      hasRoot = true;
    }
    if (depth == 2 && (event.name == 'channel' || event.name == 'programme')) {
      entry = _XmlTvEntry(kind: event.name, depth: depth, attributes: {for (final attribute in event.attributes) attribute.name: attribute.value});
      return;
    }
    if (entry != null && depth == entry!.depth + 1 && const {'title', 'desc', 'display-name'}.contains(event.name)) {
      field = event.name;
      fieldDepth = depth;
      fieldText = StringBuffer();
    }
  }

  void _append(String value) {
    final text = fieldText;
    if (text == null) return;
    final remaining = 65536 - text.length;
    if (remaining > 0) {
      text.write(value.substring(0, value.length < remaining ? value.length : remaining));
    }
  }

  void _end(XmlEndElementEvent event) {
    final currentEntry = entry;
    if (currentEntry != null && field != null && depth == fieldDepth) {
      final value = fieldText!.toString();
      if (field == 'display-name') {
        currentEntry.displayNames.add(value);
      } else {
        currentEntry.fields.putIfAbsent(field!, () => value);
      }
      field = null;
      fieldText = null;
    }
    if (currentEntry != null && depth == currentEntry.depth) {
      _finishEntry(currentEntry);
      entry = null;
    }
    depth--;
  }

  void _finishEntry(_XmlTvEntry current) {
    if (current.kind == 'channel') {
      final id = current.attributes['id'];
      if (id != null) channels.add(_GuideChannel(id, List.unmodifiable(current.displayNames)));
      return;
    }
    final channelId = current.attributes['channel'];
    final title = current.fields['title'] ?? '';
    final start = _xmltvDate(current.attributes['start']);
    final end = _xmltvDate(current.attributes['stop']);
    if (channelId == null || title.isEmpty || start == null || end == null || !end.isAfter(start) || !end.isAfter(now)) return;
    final rows = programmes.putIfAbsent(channelId, () => []);
    rows.add(_XmlTvProgramme(channelId: channelId, title: title, description: current.fields['desc'] ?? '', start: start, end: end));
    rows.sort((left, right) => left.start.compareTo(right.start));
    if (rows.length > 100) rows.removeLast();
  }
}

final class _XmlTvEntry {
  _XmlTvEntry({required this.kind, required this.depth, required this.attributes});

  final String kind;
  final int depth;
  final Map<String, String> attributes;
  final List<String> displayNames = [];
  final Map<String, String> fields = {};
}

DateTime? _xmltvDate(String? value) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*(Z|[+-]\d{4})?$').firstMatch(value ?? '');
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6) ?? '00');
  final local = DateTime.utc(year, month, day, hour, minute, second);
  if (local.year != year || local.month != month || local.day != day || local.hour != hour || local.minute != minute || local.second != second) return null;
  final zone = match.group(7) ?? 'Z';
  if (zone == 'Z') return local;
  final offsetHours = int.parse(zone.substring(1, 3));
  final offsetMinutes = int.parse(zone.substring(3, 5));
  if (offsetHours > 23 || offsetMinutes > 59) return null;
  final totalMinutes = offsetHours * 60 + offsetMinutes;
  return zone.startsWith('+') ? local.subtract(Duration(minutes: totalMinutes)) : local.add(Duration(minutes: totalMinutes));
}

String _normalizedName(String value) =>
    value.replaceFirst(RegExp(r'^[A-Z]{2}\s*-\s*', caseSensitive: false), '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
