import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:popcorn_server_core/popcorn_server_core.dart';

import 'dart_io_provider_http_client.dart';
import 'dart_resource_proxy.dart';
import 'player_page_renderer.dart';

final class DartPlayerServer {
  DartPlayerServer({
    required this.providers,
    required Set<String> apiTokens,
    this.host = '127.0.0.1',
    this.port = 0,
    PlayerAuth? auth,
    SubtitleRefStore? subtitleRefs,
    SourceRefStore? sourceRefs,
    DartResourceProxy? resourceProxy,
    ProviderHttpClient? providerHttpClient,
    IntroDbClient? introDb,
    JustWatchProviderLinks? justWatchProviderLinks,
    RadioCatalog? radioCatalog,
    LiveTvCatalog? liveTvCatalog,
    LiveTvEpg? liveTvEpg,
    ProviderStreamingHttpClient? streamingHttpClient,
  }) : auth = auth ?? PlayerAuth(apiTokens),
       subtitleRefs = subtitleRefs ?? SubtitleRefStore(),
       sourceRefs = sourceRefs ?? SourceRefStore(),
       resourceProxy = resourceProxy ?? DartResourceProxy(),
       _providedHttpClient = providerHttpClient,
       _introDb = introDb,
       _justWatchProviderLinks = justWatchProviderLinks,
       _radioCatalog = radioCatalog,
       _liveTvCatalog = liveTvCatalog,
       _liveTvEpg = liveTvEpg,
       _providedStreamingHttpClient = streamingHttpClient;

  final MediaProviderRegistry providers;
  final PlayerAuth auth;
  final SubtitleRefStore subtitleRefs;
  final SourceRefStore sourceRefs;
  final DartResourceProxy resourceProxy;
  final String host;
  final int port;
  final ProviderHttpClient? _providedHttpClient;
  final IntroDbClient? _introDb;
  final JustWatchProviderLinks? _justWatchProviderLinks;
  final RadioCatalog? _radioCatalog;
  final LiveTvCatalog? _liveTvCatalog;
  final LiveTvEpg? _liveTvEpg;
  final ProviderStreamingHttpClient? _providedStreamingHttpClient;
  late final ProviderHttpClient _httpClient = _providedHttpClient ?? DartIoProviderHttpClient();
  late final IntroDbClient _introDbClient = _introDb ?? IntroDbClient(httpClient: _httpClient);
  late final JustWatchProviderLinks _justWatchLinks = _justWatchProviderLinks ?? JustWatchProviderLinks(httpClient: _httpClient);
  late final RadioCatalog _radio = _radioCatalog ?? RadioCatalog(httpClient: _httpClient);
  late final LiveTvCatalog _liveTv = _liveTvCatalog ?? LiveTvCatalog(httpClient: _httpClient);
  late final ProviderStreamingHttpClient _streamingHttpClient = _providedStreamingHttpClient ?? _httpClient as ProviderStreamingHttpClient;
  late final LiveTvEpg _liveTvEpgService = _liveTvEpg ?? LiveTvEpg(httpClient: _httpClient, streamingHttpClient: _streamingHttpClient);
  HttpServer? _server;
  bool _stopped = false;

  Uri get baseUri {
    final address = _server?.address;
    if (address == null) throw StateError('Player server has not started.');
    final host = address.type == InternetAddressType.IPv6 ? '[${address.address}]' : address.address;
    return Uri.parse('http://$host:${_server!.port}');
  }

  bool get isRunning => _server != null;

  Future<Uri> start() async {
    if (_stopped) throw StateError('Player server has already stopped.');
    if (_server != null) throw StateError('Player server is already running.');
    final server = await HttpServer.bind(host, port, shared: false);
    _server = server;
    server.listen(
      _handleRequest,
      onError: (Object error, StackTrace stack) {
        stderr.writeln('Player server listener failed: $error');
      },
    );
    return baseUri;
  }

  Future<void> stop() async {
    _stopped = true;
    final server = _server;
    _server = null;
    await server?.close(force: true);
    await resourceProxy.close();
    if (_providedHttpClient == null && _httpClient is DartIoProviderHttpClient) {
      _httpClient.close(force: true);
    }
    for (final provider in providers.allProviders) {
      if (provider is ClosableMediaProvider) {
        await provider.close();
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
      ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Authorization, Range')
      ..set('Referrer-Policy', 'no-referrer');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }
    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    final uri = request.uri;
    final bearerToken = PlayerAuth.extractBearerToken(request.headers.value(HttpHeaders.authorizationHeader));
    if (!auth.authorize(path: uri.path, bearerToken: bearerToken, sessionId: uri.queryParameters['session'])) {
      await _writeJson(response, HttpStatus.unauthorized, {'error': 'Unauthorized'}, extraHeaders: {HttpHeaders.wwwAuthenticateHeader: 'Bearer'});
      return;
    }

    try {
      switch (uri.path) {
        case '/favicon.ico':
          response.statusCode = HttpStatus.noContent;
          await response.close();
        case '/':
          await _writeHtml(
            response,
            PlayerPageRenderer.render(
              providers: providers.list(),
              session: auth.pageSession(sessionId: uri.queryParameters['session']),
            ),
          );
        case '/player':
          final media = MediaRequest.parse(uri.queryParameters, providers: providers);
          final provider = providers.get(media.providerId);
          final embedUrl = provider is EmbedPageProvider && provider is! StreamExtractingProvider ? provider.embedUrl(media) : null;
          await _writeHtml(
            response,
            PlayerPageRenderer.render(
              providers: providers.list(),
              initialMedia: media,
              embedUrl: embedUrl,
              session: auth.pageSession(sessionId: uri.queryParameters['session']),
              showForm: false,
            ),
          );
        case '/health':
          response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
          response.write('ok');
          await response.close();
        case '/providers':
          await _writeJson(response, HttpStatus.ok, {
            'providers': [
              for (final provider in providers.list()) {'id': provider.id, 'label': provider.label},
            ],
            'defaultProvider': providers.defaultProviderId,
          });
        case '/session':
          await _writeJson(response, HttpStatus.ok, {'session': auth.createSession()});
        case '/introdb':
          await _writeJson(response, HttpStatus.ok, await _introDbClient.fetch(uri.queryParameters));
        case '/watch-providers':
          await _writeJson(
            response,
            HttpStatus.ok,
            await _justWatchLinks.resolve(
              type: uri.queryParameters['type'],
              title: uri.queryParameters['title'],
              year: uri.queryParameters['year'],
              region: uri.queryParameters['region'],
            ),
          );
        case '/radio':
          await _radioCatalogue(response, uri.queryParameters);
        case '/radio/play':
          await _writeJson(response, HttpStatus.ok, await _radio.startPlayback(uri.queryParameters['station'] ?? ''));
        case '/live-tv':
          await _writeJson(
            response,
            HttpStatus.ok,
            await _liveTv.getCatalogue(
              country: uri.queryParameters['country'] ?? '',
              channelId: uri.queryParameters['channel'],
              query: uri.queryParameters['q'] ?? '',
            ),
          );
        case '/live-tv/epg':
          await _liveTvProgrammeListing(response, uri.queryParameters['channel']);
        case '/nxsha/servers':
          await _nxshaServerListing(response, uri.queryParameters);
        case '/manifest':
          await _serveManifest(request);
        case '/sources':
          await _listSources(response, uri.queryParameters);
        case '/subtitles':
          await _listSubtitles(response, uri.queryParameters);
        default:
          if (uri.path.startsWith('/subtitle/')) {
            await _fetchSubtitle(response, uri.path.substring('/subtitle/'.length));
          } else if (uri.path.startsWith('/resource/')) {
            await resourceProxy.serveRegistered(request, uri.path.substring('/resource/'.length));
          } else {
            response.statusCode = HttpStatus.notFound;
            await response.close();
          }
      }
    } on Object catch (error) {
      await _writeFailure(response, uri.path, error);
    }
  }

  Future<void> _radioCatalogue(HttpResponse response, Map<String, String> query) async {
    final stationId = query['station'];
    if (stationId != null) {
      final station = await _radio.getStation(stationId);
      await _writeJson(response, HttpStatus.ok, {
        'stations': [if (station != null) station],
      });
      return;
    }
    await _writeJson(response, HttpStatus.ok, await _radio.getCatalogue(country: query['country'] ?? '', query: query['q'] ?? ''));
  }

  Future<void> _liveTvProgrammeListing(HttpResponse response, String? id) async {
    final channel = id == null ? null : await _liveTv.getChannel(id);
    if (channel == null) {
      await _writeJson(response, HttpStatus.notFound, {'error': 'channel_not_found'});
      return;
    }
    await _writeJson(response, HttpStatus.ok, {'programmes': await _liveTvEpgService.getProgrammes(channel)});
  }

  Future<void> _nxshaServerListing(HttpResponse response, Map<String, String> query) async {
    final parameters = {...query, 'provider': 'nxsha'};
    final media = MediaRequest.parse(parameters, providers: providers);
    final provider = providers.get(media.providerId);
    if (provider is! ServerListingProvider) {
      throw const InvalidMediaRequest('Nxsha server lookup is unavailable');
    }
    await _writeJson(response, HttpStatus.ok, await provider.listServers(media));
  }

  Future<void> _serveManifest(HttpRequest request) async {
    final media = MediaRequest.parse(request.uri.queryParameters, providers: providers);
    final provider = providers.get(media.providerId);
    if (provider is! StreamExtractingProvider) {
      throw StateError('Stream extraction is unavailable for this provider.');
    }
    final sourceId = request.uri.queryParameters['source'];
    final selectedSource = sourceId == null ? null : sourceRefs.get(sourceId, provider.id, media);
    if (sourceId != null && selectedSource == null) {
      throw const InvalidMediaRequest('Selected source expired; reload the player');
    }
    final stream = await provider.extract(media, selectedSource: selectedSource);
    final providerOrigin = provider is EmbedPageProvider ? (provider as EmbedPageProvider).embedUrl(media) : stream.uri;
    await resourceProxy.serve(request, url: stream.uri, providerId: provider.id, providerOrigin: providerOrigin);
  }

  Future<void> _listSources(HttpResponse response, Map<String, String> query) async {
    final media = MediaRequest.parse(query, providers: providers);
    final provider = providers.get(media.providerId);
    if (provider is! SourceListingProvider) {
      await _writeJson(response, HttpStatus.ok, []);
      return;
    }
    final listing = await provider.listSources(media);
    await _writeJson(response, HttpStatus.ok, [
      for (final source in listing.sources)
        {
          'id': sourceRefs.add(source.toReferenceData(token: listing.token), provider.id, media),
          'label': source.name,
          'language': source.language,
          'flag': source.flag,
        },
    ]);
  }

  Future<void> _listSubtitles(HttpResponse response, Map<String, String> query) async {
    final media = MediaRequest.parse(query, providers: providers);
    final provider = providers.get(media.providerId);
    if (provider is! SubtitleListingProvider) {
      throw StateError('Subtitle listing is unavailable for this provider.');
    }
    final tracks = await provider.listSubtitles(media);
    await _writeJson(response, HttpStatus.ok, [
      for (final track in tracks)
        if (track.ref.isNotEmpty) {'id': subtitleRefs.add(track.ref, provider.id), 'label': track.label, 'language': track.language},
    ]);
  }

  Future<void> _fetchSubtitle(HttpResponse response, String id) async {
    final reference = subtitleRefs.get(id);
    if (reference == null) {
      response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.text
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.write('Subtitle expired; reload the page');
      await response.close();
      return;
    }
    final provider = providers.get(reference.providerId);
    if (provider is! SubtitleFetchingProvider) {
      throw StateError('Subtitle fetching is unavailable for this provider.');
    }
    final content = await provider.fetchSubtitle(reference.ref);
    response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, content.contentType)
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(content.text);
    await response.close();
  }

  Future<void> _writeJson(HttpResponse response, int statusCode, Object value, {Map<String, String> extraHeaders = const {}}) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType('application', 'json', charset: 'utf-8')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    for (final entry in extraHeaders.entries) {
      response.headers.set(entry.key, entry.value);
    }
    response.write(jsonEncode(value));
    await response.close();
  }

  Future<void> _writeHtml(HttpResponse response, String html) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(html);
    await response.close();
  }

  Future<void> _writeFailure(HttpResponse response, String path, Object error) async {
    final statusCode = switch (error) {
      InvalidMediaRequest() => HttpStatus.badRequest,
      PlayerAuthException(:final statusCode) => statusCode,
      UnsupportedMediaProvider(:final statusCode) => statusCode,
      RadioCatalogException(:final statusCode) => statusCode,
      _ => _statusCodeFrom(error) ?? HttpStatus.badGateway,
    };
    stderr.writeln('Request $path failed: $error');
    if (path == '/radio' || path == '/radio/play') {
      final code = error is RadioCatalogException ? error.code : null;
      await _writeJson(response, statusCode, {'error': statusCode == HttpStatus.badRequest ? code ?? 'invalid_radio_station' : 'radio_unavailable'});
      return;
    }
    if (path == '/live-tv' || path == '/live-tv/epg') {
      await _writeJson(response, statusCode, {'error': 'live_tv_unavailable'});
      return;
    }
    if (path == '/watch-providers') {
      await _writeJson(response, statusCode, {'error': statusCode == HttpStatus.badRequest ? '$error' : 'Unable to load JustWatch provider links'});
      return;
    }
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.text
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(statusCode == HttpStatus.badRequest ? '$error' : 'Unable to load stream');
    await response.close();
  }

  int? _statusCodeFrom(Object error) {
    if (error is ProviderHttpException) return HttpStatus.badGateway;
    return null;
  }
}
