import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM for every request and reply between the two tablets. The key
/// is the per-device secret handed over once at pairing, so anyone else on
/// the Wi-Fi sees only opaque bytes and can't forge a request.
class SyncCrypto {
  const SyncCrypto._();

  static final _aes = AesGcm.with256bits();

  static Future<String> encrypt(List<int> key, String plain) async {
    final box = await _aes.encrypt(
      utf8.encode(plain),
      secretKey: SecretKey(key),
    );
    return base64Encode(box.concatenation());
  }

  /// Throws if the key is wrong or the data was altered.
  static Future<String> decrypt(List<int> key, String encoded) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(encoded),
      nonceLength: 12,
      macLength: 16,
    );
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(clear);
  }

  static final _rng = Random.secure();

  static List<int> randomKey() =>
      List<int>.generate(32, (_) => _rng.nextInt(256));

  static int randomNumber(int max) => _rng.nextInt(max);

  /// A short random token (device ids, nonces).
  static String randomToken([int bytes = 9]) => base64UrlEncode(
    List<int>.generate(bytes, (_) => _rng.nextInt(256)),
  ).replaceAll('=', '');
}
