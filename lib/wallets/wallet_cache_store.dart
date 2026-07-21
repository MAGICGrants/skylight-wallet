import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:spice_wallet/util/dirs.dart';
import 'package:spice_wallet/util/wallet_file_crypto.dart';

/// Per-coin encrypted cache of sensitive display data (balances, tx history,
/// raw tx blobs, per-scripthash state). Encrypted at rest with the wallet
/// password (AES-256-GCM via [WalletFileCrypto]), same scheme as the master
/// seed store. Lives at `${appDir}/<coin>_cache`.
class WalletCacheStore {
  WalletCacheStore._();

  static Future<File> _file(String coinSymbol) async {
    final appDir = await getAppDir();
    return File('${appDir.path}/${coinSymbol.toLowerCase()}_cache');
  }

  /// Decrypts and returns the cache map. Returns an empty map when there is no
  /// file yet or the blob can't be decrypted (wrong password / corruption).
  static Future<Map<String, dynamic>> load(String coinSymbol, String password) async {
    final file = await _file(coinSymbol);
    if (!await file.exists()) return {};
    final blob = await file.readAsString();
    if (!WalletFileCrypto.isValidEncryptedBlobBase64(blob)) return {};
    try {
      final json = await Isolate.run(() => WalletFileCrypto.decryptFromBase64(blob, password));
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(String coinSymbol, Map<String, dynamic> data, String password) async {
    final file = await _file(coinSymbol);
    final blob = await WalletFileCrypto.encryptToBase64(jsonEncode(data), password);
    await file.writeAsString(blob);
  }

  static Future<void> delete(String coinSymbol) async {
    final file = await _file(coinSymbol);
    if (await file.exists()) await file.delete();
  }
}
