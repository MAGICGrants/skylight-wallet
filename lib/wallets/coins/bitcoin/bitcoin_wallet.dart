import 'package:bitcoin_base/bitcoin_base.dart';

import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_chain_wallet.dart';

/// Bitcoin mainnet: BIP84 `m/84'/0'/0'`, [`BitcoinNetwork.mainnet`].
class BitcoinWallet extends BitcoinChainWallet {
  BitcoinWallet()
    : super(
        network: BitcoinNetwork.mainnet,
        bip84AccountPath: "m/84'/0'/0'",
        coinSymbol: 'BTC',
        coinName: 'Bitcoin',
        iconAsset: 'assets/icons/bitcoin.svg',
        connectionAddressExample: 'e.g. electrum.example.com:50002',
        isTestnet: false,
      );

  @override
  String get openAliasAsset => 'btc';
}
