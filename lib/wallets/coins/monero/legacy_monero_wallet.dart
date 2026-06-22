import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/wallets/coins/monero/monero_wallet.dart';

/// Opens v1's legacy `mywallet` file (the old polyseed-based Monero wallet) so
/// its seed can be revealed before the user deletes it. Read-only use; not
/// registered in [WalletManager]. Dispose after use.
class LegacyMoneroWallet extends MoneroWallet {
  @override
  Future<String> resolveWalletPath() => getLegacyWalletPath();

  /// The wallet's seed phrase, available after [openExisting]: the 16-word
  /// polyseed when present, otherwise the 25-word legacy seed.
  String? seedPhrase() {
    final polyseed = w2Wallet?.getPolyseed(passphrase: '');
    if (polyseed != null && polyseed.isNotEmpty) return polyseed;
    final legacy = w2Wallet?.seed(seedOffset: '');
    return (legacy != null && legacy.isNotEmpty) ? legacy : null;
  }

  /// No-op: the legacy wallet's tx history is irrelevant here and the base
  /// implementation would write `xmr_*` prefs and hit the network.
  @override
  Future<void> loadTxHistory({bool persistCount = true}) async {}
}
