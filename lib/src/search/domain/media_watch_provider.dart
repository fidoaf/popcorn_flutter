/// A legal streaming, free, ad-supported, rental, or purchase provider for a title.
final class MediaWatchProvider {
  const MediaWatchProvider({required this.id, required this.name, required this.logoUrl, this.justWatchUrl});

  final int id;
  final String name;
  final Uri logoUrl;
  final Uri? justWatchUrl;
}
