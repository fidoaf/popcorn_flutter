import 'dart:math';

import 'media_request.dart';

final class ExpiringReferenceStore<T> {
  ExpiringReferenceStore({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _generateId;

  final Duration ttl;
  final int? maxEntries;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final Map<String, _Entry<T>> _entries = {};

  String add(T value) {
    _pruneExpired();
    if (maxEntries != null && _entries.length >= maxEntries!) {
      _entries.remove(_entries.keys.first);
    }
    final id = _idGenerator();
    _entries[id] = _Entry(value, _clock().add(ttl));
    return id;
  }

  T? get(String id) {
    final entry = _entries[id];
    if (entry == null) return null;
    if (!entry.expiresAt.isAfter(_clock())) {
      _entries.remove(id);
      return null;
    }
    return entry.value;
  }

  void _pruneExpired() {
    final now = _clock();
    _entries.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
  }

  static String _generateId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final class SubtitleReference {
  const SubtitleReference({required this.ref, required this.providerId});

  final String ref;
  final String providerId;
}

final class SubtitleRefStore {
  SubtitleRefStore({
    Duration ttl = const Duration(minutes: 5),
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _store = ExpiringReferenceStore<SubtitleReference>(
         ttl: ttl,
         clock: clock,
         idGenerator: idGenerator,
       );

  final ExpiringReferenceStore<SubtitleReference> _store;

  String add(String ref, String providerId) =>
      _store.add(SubtitleReference(ref: ref, providerId: providerId));

  SubtitleReference? get(String id) => _store.get(id);
}

final class SourceReference {
  SourceReference({
    required Map<String, Object?> source,
    required this.providerId,
    required this.mediaKey,
  }) : source = Map.unmodifiable(source);

  final Map<String, Object?> source;
  final String providerId;
  final String mediaKey;
}

final class SourceRefStore {
  SourceRefStore({
    Duration ttl = const Duration(minutes: 5),
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _store = ExpiringReferenceStore<SourceReference>(
         ttl: ttl,
         clock: clock,
         idGenerator: idGenerator,
       );

  final ExpiringReferenceStore<SourceReference> _store;

  String add(
    Map<String, Object?> source,
    String providerId,
    MediaRequest media,
  ) => _store.add(
    SourceReference(
      source: source,
      providerId: providerId,
      mediaKey: _mediaKey(media),
    ),
  );

  SourceReference? get(String id, String providerId, MediaRequest media) {
    final entry = _store.get(id);
    if (entry == null ||
        entry.providerId != providerId ||
        entry.mediaKey != _mediaKey(media)) {
      return null;
    }
    return entry;
  }

  String _mediaKey(MediaRequest media) => [
    media.type,
    media.id,
    media.season,
    media.episode,
    media.lang,
    media.sub,
  ].join(':');
}

final class _Entry<T> {
  const _Entry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;
}
