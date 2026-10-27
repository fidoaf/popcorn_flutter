import 'provider_http_client.dart';

abstract interface class SameOriginBrowserFetchClient {
  Future<ProviderHttpResponse> fetch(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  });
}