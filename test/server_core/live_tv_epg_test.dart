import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

final _now = DateTime.utc(2026, 10, 15, 18);
const _channel = {'id': 'Example.fr', 'name': 'Example TV', 'feed': 'Paris', 'country': 'FR'};
const _directory = '<a href="https://iptv-epg.org/files/epg-fr.xml">FR</a>';
const _guideUri = 'https://iptv-epg.org/files/epg-fr.xml';
const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="Example.fr@Paris"><display-name>Example TV</display-name></channel>
  <programme channel="Example.fr@Paris" start="20261015193000 +0200" stop="20261015203000 +0200">
    <title>News &amp; Weather</title><desc>Evening news.</desc>
  </programme>
  <programme channel="Example.fr@Paris" start="20261015203000 +0200" stop="20261015213000 +0200"><title>Next show</title></programme>
  <programme channel="Example.fr@Paris" start="20261015163000 +0200" stop="20261015173000 +0200"><title>Past</title></programme>
  <programme channel="Other.fr" start="20261015193000 +0200" stop="20261015203000 +0200"><title>Wrong channel</title></programme>
  <programme channel="Example.fr@Paris" start="invalid" stop="20261015203000 +0200"><title>Invalid</title></programme>
</tv>''';

void main() {
  test('parses matching current and upcoming programmes with timezone offsets', () async {
    final epg = _epg({_guideUri: _xml});

    expect(await epg.getProgrammes(_channel), [
      {'title': 'News & Weather', 'description': 'Evening news.', 'start': '2026-10-15T17:30:00.000Z', 'end': '2026-10-15T18:30:00.000Z'},
      {'title': 'Next show', 'description': '', 'start': '2026-10-15T18:30:00.000Z', 'end': '2026-10-15T19:30:00.000Z'},
    ]);
  });

  test('matches a unique prefixed channel name but never merges ambiguous feeds', () async {
    final unique = _xml.replaceAll('Example.fr@Paris', 'DifferentID.fr').replaceFirst('Example TV', 'FR - Example TV');
    expect(await _epg({_guideUri: unique}).getProgrammes(_channel), hasLength(2));

    final ambiguous = unique.replaceFirst('</channel>', '</channel><channel id="Another.fr"><display-name>FR - Example TV</display-name></channel>');
    expect(await _epg({_guideUri: ambiguous}).getProgrammes(_channel), isEmpty);

    final noFeed = Map<String, Object?>.of(_channel)..remove('feed');
    final fallback = _xml.replaceFirst(
      '</tv>',
      '<channel id="Example.fr"><display-name>Example TV</display-name></channel>'
          '<programme channel="Example.fr" start="20261015193000 +0200" stop="20261015203000 +0200"><title>Base feed</title></programme></tv>',
    );
    expect((await _epg({_guideUri: fallback}).getProgrammes(noFeed)).first['title'], 'Base feed');
  });

  test('streams split UTF-8, caps results at 100 and caches guide downloads', () async {
    final rows = List.generate(105, (index) {
      final start = DateTime.utc(2026, 10, 15, 18).add(Duration(hours: index));
      final end = start.add(const Duration(hours: 1));
      String timestamp(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')} +0000';
      return '<programme channel="Example.fr"><title>Émission $index</title>'
              '<desc><![CDATA[Actualités & météo]]></desc>'
              '<start>${timestamp(start)}</start>'
              '<!-- attributes supplied below -->'
              '</programme>'
          .replaceFirst('<programme channel="Example.fr">', '<programme channel="Example.fr" start="${timestamp(start)}" stop="${timestamp(end)}">');
    }).reversed.join();
    final guide = '<tv><channel id="Example.fr"><display-name>FR - Example TV</display-name></channel>$rows</tv>';
    final client = _FakeStreamingClient({_guideUri: guide});
    final epg = LiveTvEpg(httpClient: client, streamingHttpClient: client, clock: () => _now);

    final result = await epg.getProgrammes({..._channel, 'feed': ''});
    expect(result, hasLength(100));
    expect(result.first['title'], 'Émission 0');
    expect(result.last['title'], 'Émission 99');
    expect(result.first['description'], 'Actualités & météo');
    await epg.getProgrammes({..._channel, 'feed': ''});
    expect(client.directoryRequests, 1);
    expect(client.guideRequests, 1);
  });

  test('rejects DOCTYPE, enforces the guide byte limit and retries malformed guides', () async {
    final doctype = _epg({_guideUri: '<!DOCTYPE tv><tv/>'});
    await expectLater(doctype.getProgrammes(_channel), throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('DOCTYPE'))));

    final oversized = LiveTvEpg(
      httpClient: _FakeStreamingClient({_guideUri: _xml}),
      streamingHttpClient: _FakeStreamingClient({_guideUri: _xml}),
      clock: () => _now,
      maxGuideBytes: 8,
    );
    await expectLater(oversized.getProgrammes(_channel), throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('size limit'))));

    var malformed = true;
    final retryClient = _FakeStreamingClient({_guideUri: _xml}, bodyOverride: (uri) => malformed ? '<tv><broken></tv>' : _xml);
    final retry = LiveTvEpg(httpClient: retryClient, streamingHttpClient: retryClient, clock: () => _now);
    await expectLater(retry.getProgrammes(_channel), throwsA(isA<FormatException>()));
    malformed = false;
    expect(await retry.getProgrammes(_channel), hasLength(2));
  });

  test('uses the country directory, returns empty for unknown countries and refreshes caches', () async {
    var clock = _now;
    final client = _FakeStreamingClient({_guideUri: _xml});
    final epg = LiveTvEpg(
      httpClient: client,
      streamingHttpClient: client,
      clock: () => clock,
      directoryTtl: const Duration(hours: 6),
      guideTtl: const Duration(minutes: 15),
    );
    expect(await epg.getProgrammes({..._channel, 'country': 'US'}), isEmpty);
    await epg.getProgrammes(_channel);
    await epg.getProgrammes(_channel);
    expect(client.directoryRequests, 1);
    expect(client.guideRequests, 1);
    clock = clock.add(const Duration(minutes: 16));
    await epg.getProgrammes(_channel);
    expect(client.guideRequests, 2);
    clock = clock.add(const Duration(hours: 6));
    await epg.getProgrammes(_channel);
    expect(client.directoryRequests, 2);
  });
}

LiveTvEpg _epg(Map<String, String> guides) {
  final client = _FakeStreamingClient(guides);
  return LiveTvEpg(httpClient: client, streamingHttpClient: client, clock: () => _now);
}

final class _FakeStreamingClient implements ProviderHttpClient, ProviderStreamingHttpClient {
  _FakeStreamingClient(this.guides, {this.bodyOverride});

  final Map<String, String> guides;
  final String Function(Uri uri)? bodyOverride;
  int directoryRequests = 0;
  int guideRequests = 0;

  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    directoryRequests++;
    return ProviderHttpResponse(statusCode: 200, body: _directory);
  }

  @override
  Future<ProviderHttpStreamResponse> getStream(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    guideRequests++;
    final text = bodyOverride?.call(uri) ?? guides[uri.toString()] ?? '';
    final bytes = utf8.encode(text);
    return ProviderHttpStreamResponse(
      statusCode: 200,
      body: Stream<List<int>>.fromIterable([for (var index = 0; index < bytes.length; index += 7) bytes.sublist(index, (index + 7).clamp(0, bytes.length))]),
    );
  }
}
