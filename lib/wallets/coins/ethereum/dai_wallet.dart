import 'package:spice_wallet/wallets/coins/ethereum/ethereum_chain_wallet.dart';

/// DAI on Ethereum mainnet (canonical contract). Shares the `ETH` coin's
/// address and RPC + explorer connection.
class DaiWallet extends Erc20ChainWallet {
  DaiWallet()
    : super(
        chainId: 1,
        coinSymbol: 'DAI',
        coinName: 'Dai',
        iconAsset: 'assets/icons/dai.svg',
        isTestnet: false,
        tokenContractAddress: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        tokenDecimals: 18,
        parentCoinSymbol: 'ETH',
        displayDecimals: 2,
        displaySmallerDigits: 0,
      );
}
