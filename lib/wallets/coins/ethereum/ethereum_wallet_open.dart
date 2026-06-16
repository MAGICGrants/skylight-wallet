import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';

/// Keys derived from a BIP39 mnemonic for an Ethereum account at the BIP44
/// default path `m/44'/60'/0'/0/0`. The address is identical for mainnet and
/// every EVM testnet (Sepolia) — networks differ only by chain id, not
/// derivation.
class EthereumKeys {
  EthereumKeys({required this.address, required this.privateKey});

  /// EIP-55 checksummed address (`0x...`).
  final String address;

  /// Raw 32-byte private key.
  final List<int> privateKey;

  String get privateKeyHex => BytesUtils.toHexString(privateKey);
}

/// Pure, isolate-safe derivation. The heavy step is `bip39.mnemonicToSeed`
/// (PBKDF2) — call this inside `Isolate.run` from the wallet so it never
/// blocks the UI thread.
EthereumKeys deriveEthereumKeys(String mnemonic) {
  final seed = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
  final account = Bip44.fromSeed(seed, Bip44Coins.ethereum).deriveDefaultPath;
  return EthereumKeys(
    address: account.publicKey.toAddress,
    privateKey: account.privateKey.raw,
  );
}
