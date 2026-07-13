import 'package:bitcoin_base/bitcoin_base.dart';

import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_chain_wallet.dart';

/// Bitcoin testnet as a separate coin: BIP84 `m/84'/1'/0'`,
/// [`BitcoinNetwork.testnet`]. Use a **testnet** Electrum server.
class BitcoinTestnetWallet extends BitcoinChainWallet {
  BitcoinTestnetWallet()
    : super(
        network: BitcoinNetwork.testnet,
        bip84AccountPath: "m/84'/1'/0'",
        coinSymbol: 'TBTC',
        coinName: 'Bitcoin Testnet',
        iconAsset: 'assets/icons/bitcoin_testnet.svg',
        connectionAddressExample: 'e.g. blockstream.info:993',
        isTestnet: true,
      );

  @override
  String get fiatBaseSymbol => 'BTC';
}
