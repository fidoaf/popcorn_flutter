import 'dart:convert';
import 'dart:io';

import 'package:popcorn_server_core/popcorn_server_core.dart';

final class DartIoProviderHttpClient implements ProviderHttpClient, ProviderStreamingHttpClient, ProviderHttpPostClient {
  DartIoProviderHttpClient({HttpClient? client})
      : _client = client ?? HttpClient(),
        _ownsClient = client == null;

  final HttpClient _client;
  final bool _ownsClient;

  @override
  Future<ProviderHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    final streamed = await getStream(uri, headers: headers, timeout: timeout);
    final body = await utf8.decoder.bind(streamed.body).join().timeout(timeout);
    return ProviderHttpResponse(
      statusCode: streamed.statusCode,
      body: body,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  @override
  Future<ProviderHttpStreamResponse> getStream(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    HttpClientRequest? request;
    try {
      request = await _client.getUrl(uri).timeout(timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close().timeout(timeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });
      return ProviderHttpStreamResponse(
        statusCode: response.statusCode,
        body: response.timeout(timeout),
        headers: responseHeaders,
        reasonPhrase: response.reasonPhrase,
      );
    } on Object catch (error) {
      request?.abort(error);
      rethrow;
    }
  }

  @override
  Future<ProviderHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    HttpClientRequest? request;
    try {
      request = await _client.postUrl(uri).timeout(timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.write(body);
      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(response).join().timeout(timeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });
      return ProviderHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
        headers: responseHeaders,
        reasonPhrase: response.reasonPhrase,
      );
    } on Object catch (error) {
      request?.abort(error);
      rethrow;
    }
  }

  void close({bool force = false}) {
    if (_ownsClient) _client.close(force: force);
  }
}
