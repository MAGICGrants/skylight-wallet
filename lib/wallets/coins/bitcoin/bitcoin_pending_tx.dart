import 'package:skylight_wallet/wallets/crypto_wallet.dart';

/// A signed-but-not-yet-broadcast Bitcoin transaction.
class BitcoinPendingTx implements PendingTransaction {
  @override
  final double amount;

  @override
  final double fee;

  /// Hex-encoded raw transaction ready for `blockchain.transaction.broadcast`.
  final String rawHex;

  /// Inputs that this transaction consumes, recorded so the wallet can
  /// invalidate them from its UTXO cache once the broadcast succeeds.
  final List<({String txHash, int vout})> spentOutpoints;

  BitcoinPendingTx({
    required this.amount,
    required this.fee,
    required this.rawHex,
    required this.spentOutpoints,
  });
}
