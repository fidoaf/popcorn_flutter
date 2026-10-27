import 'media_request.dart';
import 'provider_registry.dart';
import 'reference_stores.dart';

abstract interface class StreamExtractingProvider implements MediaProvider {
  Future<ResolvedStream> extract(MediaRequest media, {SourceReference? selectedSource});
}

abstract interface class SourceListingProvider implements MediaProvider {
  Future<SourceListing> listSources(MediaRequest media);
}

abstract interface class ServerListingProvider implements MediaProvider {
  Future<List<Map<String, Object?>>> listServers(MediaRequest media);
}

abstract interface class SubtitleListingProvider implements MediaProvider {
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media);
}

abstract interface class SubtitleFetchingProvider implements MediaProvider {
  Future<SubtitleContent> fetchSubtitle(String ref);
}

abstract interface class EmbedPageProvider implements MediaProvider {
  Uri embedUrl(MediaRequest media);
}

abstract interface class ClosableMediaProvider implements MediaProvider {
  Future<void> close();
}

final class ResolvedStream {
  const ResolvedStream({required this.uri, required this.type});

  final Uri uri;
  final String type;
}

final class ProviderSource {
  const ProviderSource({required this.ref, required this.name, this.language = '', this.flag = ''});

  final Object? ref;
  final String name;
  final String language;
  final String flag;

  Map<String, Object?> toReferenceData({String? token}) => {'ref': ref, if (token != null) 'token': token};
}

final class SourceListing {
  SourceListing({required Iterable<ProviderSource> sources, this.token}) : sources = List.unmodifiable(sources);

  final List<ProviderSource> sources;
  final String? token;
}

final class SubtitleTrack {
  const SubtitleTrack({required this.ref, required this.label, this.language = ''});

  final String ref;
  final String label;
  final String language;
}

final class SubtitleContent {
  const SubtitleContent({required this.text, this.contentType = 'text/vtt; charset=utf-8'});

  final String text;
  final String contentType;
}
