import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_chain_wallet.dart';

class EthereumSepoliaWallet extends EthereumChainWallet {
  EthereumSepoliaWallet()
    : super(
        chainId: 11155111,
        coinSymbol: 'SETH',
        coinName: 'Ethereum Sepolia',
        iconAsset: 'assets/icons/ethereum_sepolia.svg',
        connectionAddressExample: 'e.g. https://ethereum-sepolia-rpc.publicnode.com',
        isTestnet: true,
      );
}
