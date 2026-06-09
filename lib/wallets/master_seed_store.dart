import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:skylight_wallet/util/dirs.dart';
import 'package:skylight_wallet/util/wallet_file_crypto.dart';

/// On-disk store for the user's BIP39 master seed.
///
/// The seed is encrypted at rest with the user's wallet password
/// (AES-256-GCM via [WalletFileCrypto]). Lives next to the per-coin
/// wallet files at `${appDir}/master_seed`.
///
/// Purpose: lets us add new coins to a wallet that was originally
/// created when those coins didn't exist yet. On unlock, [WalletManager]
/// reads the master seed and bootstraps any registered coin whose own
/// wallet file is missing by calling `restoreFromMasterSeed`.
class MasterSeedStore {
  MasterSeedStore._();

  static Future<File> _file() async {
    final appDir = await getAppDir();
    return File('${appDir.path}/master_seed');
  }

  static Future<bool> exists() async => (await _file()).exists();

  static Future<void> save({
    required String bip39Mnemonic,
    required DateTime restoreDate,
    required String password,
  }) async {
    final body = jsonEncode({
      'v': 1,
      'mnemonic': bip39Mnemonic,
      'restore_date_iso': restoreDate.toIso8601String(),
    });
    final file = await _file();
    await file.writeAsString(await WalletFileCrypto.encryptToBase64(body, password));
  }

  /// Decrypts and returns the stored seed. Returns `null` if no file
  /// exists; throws on a decryption / format error (which the caller
  /// should treat as "wrong password").
  static Future<({String mnemonic, DateTime restoreDate})?> load(String password) async {
    final file = await _file();
    if (!await file.exists()) return null;
    final blob = await file.readAsString();
    return Isolate.run(() => _decryptSeed(blob, password));
  }

  static Future<({String mnemonic, DateTime restoreDate})> _decryptSeed(
    String blob,
    String password,
  ) async {
    final body = jsonDecode(await WalletFileCrypto.decryptFromBase64(blob, password))
        as Map<String, dynamic>;
    final mnemonic = body['mnemonic'] as String;
    final restoreDate =
        DateTime.tryParse(body['restore_date_iso'] as String? ?? '') ?? DateTime.now();
    return (mnemonic: mnemonic, restoreDate: restoreDate);
  }

  static Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
