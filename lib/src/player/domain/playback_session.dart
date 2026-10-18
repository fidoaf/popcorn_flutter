final class PlaybackSession {
  const PlaybackSession({this.provider, this.source, this.language, this.subtitles, this.subtitleDelaySeconds = 0, this.positionSeconds = 0});

  final String? provider;
  final String? source;
  final String? language;
  final String? subtitles;

  /// Signed offset in seconds: positive delays subtitles, negative advances them.
  final double subtitleDelaySeconds;
  final double positionSeconds;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'source': source,
    'language': language,
    'subtitles': subtitles,
    'subtitleDelaySeconds': subtitleDelaySeconds,
    'positionSeconds': positionSeconds,
  };

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final position = (json['positionSeconds'] as num?)?.toDouble() ?? 0;
    final subtitleDelay = (json['subtitleDelaySeconds'] as num?)?.toDouble() ?? 0;
    return PlaybackSession(
      provider: json['provider'] as String?,
      source: json['source'] as String?,
      language: json['language'] as String?,
      subtitles: json['subtitles'] as String?,
      subtitleDelaySeconds: subtitleDelay.isFinite ? subtitleDelay : 0,
      positionSeconds: position.isFinite && position >= 0 ? position : 0,
    );
  }
}
