/// Mutable, externally-controlled playback preferences injected into media
/// source requests at resolve time.
///
/// The active [ConfigurableMediaSourceProvider] exposes a single instance so
/// the app (settings screen, user profile, etc.) can change the [language] or
/// [subtitles] at runtime without knowing anything about the underlying
/// request templates. The values are surfaced as the `{language}` and
/// `{subtitles}` placeholders that a `MediaSourceProviderDefinition` may
/// reference.
final class MediaSourcePreferences {
  MediaSourcePreferences({this.language = 'en', this.subtitles = true});

  /// Preferred language code, substituted for the `{language}` placeholder.
  String language;

  /// Whether subtitles are requested; substituted for the `{subtitles}`
  /// placeholder as `1` (enabled) or `0` (disabled).
  bool subtitles;

  /// Placeholder variables contributed to request templates.
  Map<String, String> get variables => {'language': language, 'subtitles': subtitles ? '1' : '0'};
}
