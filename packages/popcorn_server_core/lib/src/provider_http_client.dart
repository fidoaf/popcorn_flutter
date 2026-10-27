abstract interface class ProviderHttpClient {
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout});
}

abstract interface class ProviderHttpPostClient {
  Future<ProviderHttpResponse> post(Uri uri, {required Map<String, String> headers, required String body, required Duration timeout});
}

abstract interface class ProviderStreamingHttpClient {
  Future<ProviderHttpStreamResponse> getStream(Uri uri, {required Map<String, String> headers, required Duration timeout});
}

final class ProviderHttpStreamResponse {
  ProviderHttpStreamResponse({required this.statusCode, required this.body, Map<String, String> headers = const {}, this.reasonPhrase = ''})
    : headers = Map.unmodifiable(headers);

  final int statusCode;
  final Stream<List<int>> body;
  final Map<String, String> headers;
  final String reasonPhrase;

  String? header(String name) {
    final normalizedName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalizedName) return entry.value;
    }
    return null;
  }
}

final class ProviderHttpResponse {
  ProviderHttpResponse({required this.statusCode, required this.body, Map<String, String> headers = const {}, this.reasonPhrase = ''})
    : headers = Map.unmodifiable(headers);

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final String reasonPhrase;

  String? header(String name) {
    final normalizedName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalizedName) return entry.value;
    }
    return null;
  }
}

final class ProviderHttpException implements Exception {
  const ProviderHttpException(this.message);

  final String message;

  @override
  String toString() => message;
}
