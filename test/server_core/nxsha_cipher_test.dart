import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('decodes the existing Node Nxsha ciphertext vector', () {
    final decoded = decodeNxshaData(
      'U2FsdGVkX18aoDPHk9dZwZNy4KOFL5-kijOziEAXE7QFs-ejFgDweENZ2VVg8wHVp4rZnfDkVLmDPK2E-vSztiAvKOA_R632b73qmwDC1Xsyn5ePnwYsmnH2GyPV7ZkWDSHaPEnoe0JBgXeS9DTh5cSUAOsgb_RrtK0NH9QY4EywPVZ8hEq6bpbcdhC6mLBw',
    );

    expect(decoded, {'tmdbId': 969681, 'imdb_id': '', 'type': 'movie', 'season': 1, 'episode': 1});
  });

  test('encodes values in an OpenSSL Salted envelope and decodes them back', () {
    final encrypted = encodeNxshaData(
      {'type': 'tv', 'id': '1399', 'season': 2},
      clock: () => DateTime.fromMillisecondsSinceEpoch(1234),
      saltTextGenerator: () => 'request-salt',
      binarySaltGenerator: () => Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]),
    );

    expect(encrypted, startsWith('U2FsdGVkX18'));
    expect(decodeNxshaData(encrypted), {'type': 'tv', 'id': '1399', 'season': 2});
  });

  test('returns null for unencrypted or corrupt values', () {
    expect(decodeNxshaData(null), isNull);
    expect(decodeNxshaData('not-encrypted'), isNull);
    expect(decodeNxshaData('U2FsdGVkX18='), isNull);
  });
}
