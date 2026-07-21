import 'package:spice_wallet/wallets/crypto_wallet.dart';

class EthereumPendingTx implements PendingTransaction {
  EthereumPendingTx({
    required this.amount,
    required this.fee,
    required this.valueWei,
    required this.feeWei,
    required this.rawHex,
    required this.txHash,
    required this.to,
  });

  @override
  final double amount;
  @override
  final double fee;

  /// Exact send value and max fee in wei (avoids the double rounding of
  /// [amount]/[fee] when recording history).
  final BigInt valueWei;
  final BigInt feeWei;

  /// Signed transaction, 0x-prefixed hex, ready for `eth_sendRawTransaction`.
  final String rawHex;

  /// Precomputed transaction hash (keccak256 of the signed payload).
  final String txHash;

  final String to;
}
