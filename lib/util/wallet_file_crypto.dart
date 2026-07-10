import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:webcrypto/webcrypto.dart' show Hash, Pbkdf2SecretKey;

/// AES-256-GCM at-rest encryption for wallet files, keyed via PBKDF2-HMAC-SHA256.
///
/// Blob: `magic(4) | version(1) | iterations(4) | salt(32) | iv(12) | ct+tag`.
class WalletFileCrypto {
  static const _magic = [0x53, 0x4B, 0x4C, 0x57]; // 'SKLW'
  static const _version = 1;
  static const _saltLen = 32;
  static const _ivLen = 12;
  static const _keyLen = 32;
  static const _tagLenBits = 128;

  // Low on mobile (random 128-bit password); OWASP count on desktop (user-chosen).
  static int get _pbkdf2Iterations => (Platform.isAndroid || Platform.isIOS) ? 100000 : 600000;

  /// Smallest on-disk blob that [decrypt] accepts (empty plaintext + GCM tag).
  static const int minBlobLength = 4 + 1 + 4 + 32 + 12 + 16;

  static final _random = Random.secure();

  /// Returns false for empty, truncated, or non-base64 wallet files.
  static bool isValidEncryptedBlobBase64(String base64Blob) {
    final trimmed = base64Blob.trim();
    if (trimmed.isEmpty) return false;
    try {
      return base64.decode(trimmed).length >= minBlobLength;
    } catch (_) {
      return false;
    }
  }

  /// Encrypts [plaintext] with [password]. Returns a base64-encoded blob
  /// suitable for writing to a text file.
  static Future<String> encryptToBase64(String plaintext, String password) async {
    final blob = await encrypt(utf8.encode(plaintext), password);
    return base64.encode(blob);
  }

  /// Decrypts a blob previously produced by [encryptToBase64].
  static Future<String> decryptFromBase64(String base64Blob, String password) async {
    final blob = base64.decode(base64Blob);
    final plaintext = await decrypt(blob, password);
    return utf8.decode(plaintext);
  }

  static Future<Uint8List> encrypt(List<int> plaintext, String password) async {
    final salt = _randomBytes(_saltLen);
    final iv = _randomBytes(_ivLen);
    final iterations = _pbkdf2Iterations;
    final key = await _deriveKey(password, salt, iterations);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _tagLenBits, iv, Uint8List(0)));

    final ciphertext = cipher.process(Uint8List.fromList(plaintext));

    final iterationsBytes = Uint8List(4)..buffer.asByteData().setUint32(0, iterations, Endian.big);

    final out = BytesBuilder()
      ..add(_magic)
      ..addByte(_version)
      ..add(iterationsBytes)
      ..add(salt)
      ..add(iv)
      ..add(ciphertext);
    return out.toBytes();
  }

  static Future<Uint8List> decrypt(List<int> blob, String password) async {
    if (blob.length < minBlobLength) {
      throw FormatException('Wallet blob is too short');
    }

    var offset = 0;
    for (var i = 0; i < _magic.length; i++) {
      if (blob[offset + i] != _magic[i]) {
        throw FormatException('Wallet blob magic mismatch');
      }
    }
    offset += _magic.length;

    final version = blob[offset++];
    if (version != _version) {
      throw FormatException('Unsupported wallet blob version: $version');
    }

    final iterations = ByteData.sublistView(
      Uint8List.fromList(blob.sublist(offset, offset + 4)),
    ).getUint32(0, Endian.big);
    offset += 4;

    final salt = Uint8List.fromList(blob.sublist(offset, offset + _saltLen));
    offset += _saltLen;
    final iv = Uint8List.fromList(blob.sublist(offset, offset + _ivLen));
    offset += _ivLen;
    final ciphertext = Uint8List.fromList(blob.sublist(offset));

    final key = await _deriveKey(password, salt, iterations);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), _tagLenBits, iv, Uint8List(0)));

    try {
      return cipher.process(ciphertext);
    } on InvalidCipherTextException {
      throw FormatException('Wallet decryption failed (wrong password or corrupt file)');
    }
  }

  // Native PBKDF2 (BoringSSL via FFI) — ~10-50x faster than pure-Dart and
  // safe to call inside Isolate.run (no platform channel).
  static Future<Uint8List> _deriveKey(String password, Uint8List salt, int iterations) async {
    final key = await Pbkdf2SecretKey.importRawKey(utf8.encode(password));
    return key.deriveBits(_keyLen * 8, Hash.sha256, salt, iterations);
  }

  static Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }
}
