import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A stream candidate considered during racing.
@immutable
final class StreamCandidate {
  const StreamCandidate({required this.url, this.headers = const <String, String>{}, this.isHls = true});

  final Uri url;
  final Map<String, String> headers;

  /// HLS playlists are validated by their `#EXTM3U` marker; non-HLS (e.g. MP4)
  /// candidates are accepted on any successful response.
  final bool isHls;
}

/// Picks the fastest working stream from a set of [StreamCandidate]s, mirroring
/// the reference HTML player's latency race: every candidate is probed in
/// parallel and the first one that validates wins. Candidates keep their input
/// order as a tie-breaker so a preferred source is favoured on equal footing.
abstract final class StreamRacer {
  const StreamRacer._();

  static const _probeTimeout = Duration(milliseconds: 2500);

  /// Races [candidates] and completes with the winner, or `null` when none
  /// validate within [_probeTimeout]. A single candidate is returned without a
  /// network probe.
  static Future<StreamCandidate?> fastest(List<StreamCandidate> candidates) async {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    final completer = Completer<StreamCandidate?>();
    var pending = candidates.length;
    // Lower index wins ties, so track the best validated candidate seen so far.
    var bestIndex = candidates.length;
    StreamCandidate? best;

    void settle() {
      if (!completer.isCompleted) completer.complete(best);
    }

    for (var i = 0; i < candidates.length; i++) {
      final index = i;
      final candidate = candidates[index];
      _probe(candidate).then((ok) {
        if (ok && index < bestIndex) {
          bestIndex = index;
          best = candidate;
          // The first-ranked candidate can never be beaten; finish immediately.
          if (index == 0) settle();
        }
        if (--pending == 0) settle();
      });
    }

    return completer.future;
  }

  static Future<bool> _probe(StreamCandidate candidate) async {
    try {
      final response = await http.get(candidate.url, headers: candidate.headers).timeout(_probeTimeout);
      if (response.statusCode < 200 || response.statusCode >= 400) return false;
      if (!candidate.isHls) return true;
      return response.body.contains('#EXTM3U');
    } catch (_) {
      return false;
    }
  }
}
