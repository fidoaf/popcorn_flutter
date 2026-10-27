import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:popcorn_server_core/popcorn_server_core.dart';

final class DartResourceProxy {
  DartResourceProxy({
    HttpClient? client,
    this.timeout = const Duration(seconds: 10),
    this.resourceTtl = const Duration(minutes: 30),
    this.maxResources = 10000,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _client = client ?? HttpClient(),
        _ownsClient = client == null,
        _resources = ExpiringReferenceStore<_ProxyResource>(
          ttl: resourceTtl,
          maxEntries: maxResources,
          clock: clock,
          idGenerator: idGenerator ?? _generateResourceId,
        );

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final HttpClient _client;
  final bool _ownsClient;
  final Duration timeout;
  final Duration resourceTtl;
  final int maxResources;
  final ExpiringReferenceStore<_ProxyResource> _resources;

  Future<void> serve(
    HttpRequest request, {
    required Uri url,
    required String providerId,
    required Uri providerOrigin,
  }) async {
    final upstream = await _fetchWithRetry(
      url,
      providerOrigin: providerOrigin,
      range: request.headers.value(HttpHeaders.rangeHeader),
    );
    final response = request.response;
    if (upstream.statusCode != HttpStatus.ok &&
        upstream.statusCode != HttpStatus.partialContent) {
      await upstream.drain<void>();
      response
        ..statusCode = HttpStatus.badGateway
        ..headers.contentType = ContentType.text;
      response.write('Upstream returned ${upstream.statusCode}');
      await response.close();
      return;
    }

    final contentType = upstream.headers.contentType?.mimeType ?? '';
    if (contentType.toLowerCase().contains('mpegurl') ||
        RegExp(r'\.m3u8(?:\?|$)', caseSensitive: false)
            .hasMatch(url.toString())) {
      final body = await utf8.decoder.bind(upstream).join();
      if (!body.startsWith('#EXTM3U')) {
        throw const FormatException('Invalid HLS playlist');
      }
      response
        ..statusCode = HttpStatus.ok
        ..headers.set(
          HttpHeaders.contentTypeHeader,
          'application/vnd.apple.mpegurl',
        )
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final session = request.uri.queryParameters['session'];
      response.write(
          _rewriteManifest(body, url, providerId, providerOrigin, session));
      await response.close();
      return;
    }

    response
      ..statusCode = upstream.statusCode
      ..headers.set(
        HttpHeaders.contentTypeHeader,
        contentType.isEmpty ? 'application/octet-stream' : contentType,
      )
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final contentRange = upstream.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
    }
    final acceptRanges = upstream.headers.value(HttpHeaders.acceptRangesHeader);
    if (acceptRanges != null) {
      response.headers.set(HttpHeaders.acceptRangesHeader, acceptRanges);
    }
    try {
      await response.addStream(upstream);
    } on Object {
      await response.close();
      return;
    }
    await response.close();
  }

  Future<void> serveRegistered(HttpRequest request, String key) async {
    final resource = _resources.get(key);
    if (resource == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    await serve(
      request,
      url: resource.url,
      providerId: resource.providerId,
      providerOrigin: resource.providerOrigin,
    );
  }

  Future<void> close() async {
    if (_ownsClient) _client.close(force: true);
  }

  String _rewriteManifest(
    String body,
    Uri manifestUrl,
    String providerId,
    Uri providerOrigin,
    String? session,
  ) =>
      body.split('\n').map((line) {
        if (line.trim().isEmpty) return line;
        if (!line.startsWith('#')) {
          return _localUrl(
              line.trim(), manifestUrl, providerId, providerOrigin, session);
        }
        return line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
          return 'URI="${_localUrl(match.group(1)!, manifestUrl, providerId, providerOrigin, session)}"';
        });
      }).join('\n');

  String _localUrl(
    String value,
    Uri baseUrl,
    String providerId,
    Uri providerOrigin,
    String? session,
  ) {
    final key = _resources.add(
      _ProxyResource(
        url: baseUrl.resolve(value),
        providerId: providerId,
        providerOrigin: providerOrigin,
      ),
    );
    final localUri = Uri(path: '/resource/$key');
    return session == null || session.isEmpty
        ? localUri.toString()
        : localUri.replace(queryParameters: {'session': session}).toString();
  }

  Future<HttpClientResponse> _fetchWithRetry(
    Uri url, {
    required Uri providerOrigin,
    String? range,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      HttpClientRequest? request;
      try {
        request = await _client.getUrl(url).timeout(timeout);
        request.headers
          ..set(HttpHeaders.userAgentHeader, _userAgent)
          ..set(HttpHeaders.refererHeader, '${providerOrigin.origin}/');
        if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
        final response = await request.close().timeout(timeout);
        if (response.statusCode < HttpStatus.internalServerError) {
          return response;
        }
        lastError =
            HttpException('Upstream returned ${response.statusCode}', uri: url);
        await response.drain<void>();
      } on Object catch (error) {
        lastError = error;
        request?.abort(error);
      }
      stderr.writeln(
          'Upstream attempt $attempt failed for ${url.host}: $lastError');
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    throw lastError ?? HttpException('Upstream request failed', uri: url);
  }
}

final class _ProxyResource {
  const _ProxyResource({
    required this.url,
    required this.providerId,
    required this.providerOrigin,
  });

  final Uri url;
  final String providerId;
  final Uri providerOrigin;
}

String _generateResourceId() {
  final random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
