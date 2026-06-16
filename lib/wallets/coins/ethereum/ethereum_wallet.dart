import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_chain_wallet.dart';

class EthereumWallet extends EthereumChainWallet {
  EthereumWallet()
    : super(
        chainId: 1,
        coinSymbol: 'ETH',
        coinName: 'Ethereum',
        iconAsset: 'assets/icons/ethereum.svg',
        connectionAddressExample: 'e.g. https://ethereum-rpc.publicnode.com',
        isTestnet: false,
      );
}
