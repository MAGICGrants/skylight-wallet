import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_chain_wallet.dart';

/// DAI on Ethereum Sepolia (Aave faucet "DAI - Faucet Open" test token).
/// Shares the `SETH` coin's address and RPC + explorer connection.
class DaiSepoliaWallet extends Erc20ChainWallet {
  DaiSepoliaWallet()
    : super(
        chainId: 11155111,
        coinSymbol: 'SDAI',
        coinName: 'Dai Sepolia',
        iconAsset: 'assets/icons/dai_sepolia.svg',
        isTestnet: true,
        tokenContractAddress: '0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357',
        tokenDecimals: 18,
        parentCoinSymbol: 'SETH',
        displayDecimals: 2,
        displaySmallerDigits: 0,
      );

  @override
  String get fiatBaseSymbol => 'DAI';
}
