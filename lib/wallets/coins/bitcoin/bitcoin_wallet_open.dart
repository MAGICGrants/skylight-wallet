import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

import 'package:skylight_wallet/util/wallet_file_crypto.dart';

/// Plain data returned from background wallet open / bootstrap crypto.
class BitcoinWalletOpenResult {
  const BitcoinWalletOpenResult({
    required this.mnemonic,
    required this.restoreDateIso,
    required this.nextReceiveIndex,
    required this.nextChangeIndex,
    required this.addresses,
    this.accountXprv,
  });

  final String mnemonic;
  final String? restoreDateIso;
  final int nextReceiveIndex;
  final int nextChangeIndex;
  final List<BitcoinAddressOpenResult> addresses;

  /// Serialized extended private key for the BIP84 account node. Set when
  /// the isolate already derived it; main thread reimports via
  /// [Bip32Slip10Secp256k1.fromExtendedKey] instead of re-running
  /// `mnemonicToSeed` + path derive.
  final String? accountXprv;
}

class BitcoinAddressOpenResult {
  const BitcoinAddressOpenResult({
    required this.index,
    required this.isChange,
    required this.address,
    required this.scriptHash,
  });

  final int index;
  final bool isChange;
  final String address;
  final String scriptHash;
}

BitcoinNetwork networkForCoinSymbol(String coinSymbol, {bool isTestnet = false}) {
  if (isTestnet) return BitcoinNetwork.testnet;
  return coinSymbol == 'TBTC' ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
}

/// Decrypts the on-disk blob and returns the wallet state needed to bring the
/// wallet up on the main isolate. Runs off the UI thread.
///
/// When the file carries the cached `addresses` set this path skips the
/// expensive BIP32/secp256k1 work entirely. Files without it (e.g. written
/// while the address cache is disabled) fall back to re-deriving from the
/// mnemonic; the next `store()` rewrites the cached set if enabled.
///
/// The caller still rebuilds [Bip32Slip10Secp256k1] on the main isolate for
/// signing.
Future<({BitcoinWalletOpenResult open, int decryptMs, int deriveMs})>
openBitcoinWalletFromEncryptedBlob({
  required String blob,
  required String password,
  required String bip84AccountPath,
  required String coinSymbol,
  required bool isTestnet,
  required int externalChain,
  required int internalChain,
}) async {
  if (!WalletFileCrypto.isValidEncryptedBlobBase64(blob)) {
    throw FormatException('Wallet blob is too short');
  }

  final decryptSw = Stopwatch()..start();
  final json =
      jsonDecode(await WalletFileCrypto.decryptFromBase64(blob, password)) as Map<String, dynamic>;
  decryptSw.stop();

  final mnemonic = json['mnemonic'] as String;
  final nextReceiveIndex = (json['next_receive_index'] as num?)?.toInt() ?? 0;
  final nextChangeIndex = (json['next_change_index'] as num?)?.toInt() ?? 0;
  final restoreDateIso = json['restore_date_iso'] as String?;
  final storedXprv = json['account_xprv'] as String?;

  final deriveSw = Stopwatch()..start();
  final cached = _decodeCachedAddresses(json['addresses']);
  if (cached != null) {
    // Use the stored xprv when present (no seed/path work); otherwise derive
    // it to seed _requireAccountHd's cheap fromExtendedKey path.
    final xprv = storedXprv ?? _deriveAccountXprv(mnemonic, bip84AccountPath);
    deriveSw.stop();
    return (
      open: BitcoinWalletOpenResult(
        mnemonic: mnemonic,
        restoreDateIso: restoreDateIso,
        nextReceiveIndex: nextReceiveIndex,
        nextChangeIndex: nextChangeIndex,
        addresses: cached,
        accountXprv: xprv,
      ),
      decryptMs: decryptSw.elapsedMilliseconds,
      deriveMs: deriveSw.elapsedMilliseconds,
    );
  }

  // No cached addresses. Derive only enough to make getReceiveAddress()
  // non-blocking; refresh()'s _ensureAddressesUpTo will lazily grow past the
  // gap limit and the next store() writes the cached set if enabled.
  final open = bootstrapBitcoinWalletFromMnemonic(
    mnemonic: mnemonic,
    bip84AccountPath: bip84AccountPath,
    coinSymbol: coinSymbol,
    isTestnet: isTestnet,
    gapLimit: 1,
    externalChain: externalChain,
    internalChain: internalChain,
    nextReceiveIndex: nextReceiveIndex,
    nextChangeIndex: nextChangeIndex,
    restoreDateIso: restoreDateIso,
  );
  deriveSw.stop();
  return (open: open, decryptMs: decryptSw.elapsedMilliseconds, deriveMs: deriveSw.elapsedMilliseconds);
}

Bip32Slip10Secp256k1 _deriveAccountHdNode(String mnemonic, String bip84AccountPath) {
  final seedBytes = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
  return Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath(bip84AccountPath)
      as Bip32Slip10Secp256k1;
}

String _deriveAccountXprv(String mnemonic, String bip84AccountPath) =>
    _deriveAccountHdNode(mnemonic, bip84AccountPath).privateKey.toExtended;

List<BitcoinAddressOpenResult>? _decodeCachedAddresses(Object? raw) {
  if (raw is! List) return null;
  final out = <BitcoinAddressOpenResult>[];
  for (final entry in raw) {
    if (entry is! Map) return null;
    final index = (entry['index'] as num?)?.toInt();
    final isChange = entry['is_change'] as bool?;
    final address = entry['address'] as String?;
    final scriptHash = entry['script_hash'] as String?;
    if (index == null || isChange == null || address == null || scriptHash == null) {
      return null;
    }
    out.add(
      BitcoinAddressOpenResult(
        index: index,
        isChange: isChange,
        address: address,
        scriptHash: scriptHash,
      ),
    );
  }
  return out;
}

BitcoinWalletOpenResult bootstrapBitcoinWalletFromMnemonic({
  required String mnemonic,
  required String bip84AccountPath,
  required String coinSymbol,
  required bool isTestnet,
  required int gapLimit,
  required int externalChain,
  required int internalChain,
  int nextReceiveIndex = 0,
  int nextChangeIndex = 0,
  String? restoreDateIso,
}) {
  final network = networkForCoinSymbol(coinSymbol, isTestnet: isTestnet);
  final seedBytes = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
  final accountHd = Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath(bip84AccountPath)
      as Bip32Slip10Secp256k1;

  final receiveCount = nextReceiveIndex + gapLimit;
  final changeCount = nextChangeIndex + gapLimit;

  final addresses = <BitcoinAddressOpenResult>[];
  for (final (:chain, :count, :isChange) in [
    (chain: externalChain, count: receiveCount, isChange: false),
    (chain: internalChain, count: changeCount, isChange: true),
  ]) {
    for (var i = 0; i < count; i++) {
      final hd = accountHd.childKey(Bip32KeyIndex(chain)).childKey(Bip32KeyIndex(i));
      final pub = ECPublic.fromBip32(hd.publicKey);
      final addressStr = pub.toP2wpkhAddress().toAddress(network);
      final scriptHash = BitcoinAddressUtils.scriptHash(addressStr, network: network);
      addresses.add(
        BitcoinAddressOpenResult(
          index: i,
          isChange: isChange,
          address: addressStr,
          scriptHash: scriptHash,
        ),
      );
    }
  }

  return BitcoinWalletOpenResult(
    mnemonic: mnemonic,
    restoreDateIso: restoreDateIso,
    nextReceiveIndex: nextReceiveIndex,
    nextChangeIndex: nextChangeIndex,
    addresses: addresses,
    accountXprv: accountHd.privateKey.toExtended,
  );
}
