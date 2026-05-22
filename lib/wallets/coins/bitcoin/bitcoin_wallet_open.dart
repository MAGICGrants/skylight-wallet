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
  });

  final String mnemonic;
  final String? restoreDateIso;
  final int nextReceiveIndex;
  final int nextChangeIndex;
  final List<BitcoinAddressOpenResult> addresses;
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

/// Decrypts the on-disk blob and derives the initial address set off the UI
/// thread. The caller still rebuilds [Bip32Slip10Secp256k1] on the main
/// isolate for signing.
BitcoinWalletOpenResult openBitcoinWalletFromEncryptedBlob({
  required String blob,
  required String password,
  required String bip84AccountPath,
  required String coinSymbol,
  required bool isTestnet,
  required int gapLimit,
  required int externalChain,
  required int internalChain,
}) {
  if (!WalletFileCrypto.isValidEncryptedBlobBase64(blob)) {
    throw FormatException('Wallet blob is too short');
  }

  final json =
      jsonDecode(WalletFileCrypto.decryptFromBase64(blob, password)) as Map<String, dynamic>;

  final mnemonic = json['mnemonic'] as String;
  final nextReceiveIndex = (json['next_receive_index'] as num?)?.toInt() ?? 0;
  final nextChangeIndex = (json['next_change_index'] as num?)?.toInt() ?? 0;
  final restoreDateIso = json['restore_date_iso'] as String?;

  return bootstrapBitcoinWalletFromMnemonic(
    mnemonic: mnemonic,
    bip84AccountPath: bip84AccountPath,
    coinSymbol: coinSymbol,
    isTestnet: isTestnet,
    gapLimit: gapLimit,
    externalChain: externalChain,
    internalChain: internalChain,
    nextReceiveIndex: nextReceiveIndex,
    nextChangeIndex: nextChangeIndex,
    restoreDateIso: restoreDateIso,
  );
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
  );
}
