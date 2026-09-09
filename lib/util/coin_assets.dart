import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_ethereum/wallet_ethereum.dart';

/// A wallet that is a token on another chain (e.g. DAI on Ethereum). Tokens are
/// hidden from the main home list and shown inside their parent chain's assets
/// list instead; they share the parent's connection.
bool isTokenWallet(CryptoWallet wallet) => wallet is Erc20ChainWallet;

/// The tokens registered on [chainSymbol] (DAI for ETH, SDAI for SETH).
List<CryptoWallet> tokensOf(WalletManager manager, String chainSymbol) => manager.allWallets
    .where((w) => w is Erc20ChainWallet && w.parentCoinSymbol == chainSymbol)
    .toList();

/// A chain's full asset list: the chain coin itself followed by its tokens.
List<CryptoWallet> chainAssets(WalletManager manager, CryptoWallet chain) => [
  chain,
  ...tokensOf(manager, chain.coinSymbol),
];

/// The chain a wallet settles on: its parent chain for a token, else itself.
String chainSymbolOf(CryptoWallet wallet) =>
    wallet is Erc20ChainWallet ? wallet.parentCoinSymbol : wallet.coinSymbol;

/// Every asset selectable on this wallet's chain (chain coin + its tokens),
/// whether [wallet] is the chain coin or one of its tokens. A single-element
/// list means the chain has no tokens (no asset picker needed).
List<CryptoWallet> assetsOnChainOf(WalletManager manager, CryptoWallet wallet) {
  final chain = manager.getWallet(chainSymbolOf(wallet));
  return chain == null ? [wallet] : chainAssets(manager, chain);
}

/// Sum of a wallet's own unlocked fiat plus that of its tokens, in [fiatRateFor]
/// units. Returns null only when nothing can be priced yet.
double? aggregateUnlockedFiat(
  WalletManager manager,
  CryptoWallet chain,
  double? Function(String coinSymbol) fiatRateFor,
) {
  double? total;
  for (final asset in chainAssets(manager, chain)) {
    final rate = fiatRateFor(asset.coinSymbol);
    final balance = asset.unlockedBalance;
    if (rate == null || balance is! double) continue;
    total = (total ?? 0) + balance * rate;
  }
  return total;
}
