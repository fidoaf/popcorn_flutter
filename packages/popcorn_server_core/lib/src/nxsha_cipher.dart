import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const _passphrase = r'S8x!Jk4ZP1uG8$my';
final _opensslSaltedHeader = Uint8List.fromList(utf8.encode('Salted__'));

Map<String, Object?>? decodeNxshaData(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  try {
    final input = Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
    if (input.length <= 16 || !_startsWith(input, _opensslSaltedHeader)) {
      return null;
    }
    final salt = Uint8List.sublistView(input, 8, 16);
    final ciphertext = Uint8List.sublistView(input, 16);
    if (ciphertext.length % 16 != 0) {
      return null;
    }
    final (key, iv) = _deriveKeyAndIv(salt);
    final plaintext = _aesCbc(key, iv, ciphertext, encrypt: false);
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map) {
      return null;
    }
    final result = Map<String, Object?>.from(decoded);
    result.remove('_req_ts');
    result.remove('_req_salt');
    return result;
  } on Object {
    return null;
  }
}

String encodeNxshaData(
  Map<String, Object?> value, {
  DateTime Function()? clock,
  String Function()? saltTextGenerator,
  Uint8List Function()? binarySaltGenerator,
}) {
  final random = Random.secure();
  final request = <String, Object?>{
    ...value,
    '_req_ts': (clock ?? DateTime.now)().millisecondsSinceEpoch,
    '_req_salt': (saltTextGenerator ?? () => base64UrlEncode(List<int>.generate(8, (_) => random.nextInt(256))).substring(0, 10))(),
  };
  final salt = binarySaltGenerator?.call() ?? Uint8List.fromList(List<int>.generate(8, (_) => random.nextInt(256)));
  if (salt.length != 8) {
    throw ArgumentError.value(salt.length, 'binarySaltGenerator', 'Salt must be exactly 8 bytes');
  }
  final (key, iv) = _deriveKeyAndIv(salt);
  final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(request)));
  final ciphertext = _aesCbc(key, iv, plaintext, encrypt: true);
  return base64UrlEncode(Uint8List.fromList([..._opensslSaltedHeader, ...salt, ...ciphertext])).replaceAll('=', '');
}

(Uint8List, Uint8List) _deriveKeyAndIv(Uint8List salt) {
  final passphrase = Uint8List.fromList(utf8.encode(_passphrase));
  final digest = MD5Digest();
  final material = <int>[];
  var previous = Uint8List(0);
  while (material.length < 48) {
    final block = Uint8List.fromList([...previous, ...passphrase, ...salt]);
    previous = digest.process(block);
    material.addAll(previous);
  }
  return (Uint8List.fromList(material.sublist(0, 32)), Uint8List.fromList(material.sublist(32, 48)));
}

Uint8List _aesCbc(Uint8List key, Uint8List iv, Uint8List input, {required bool encrypt}) {
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
  cipher.init(encrypt, PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(ParametersWithIV<KeyParameter>(KeyParameter(key), iv), null));
  return cipher.process(input);
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}
