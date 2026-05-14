// ignore_for_file: implementation_imports
import 'package:monero/src/monero.dart';

import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

/// Adapter that exposes a [MoneroPendingTransaction] through the
/// coin-agnostic [PendingTransaction] interface so UI code does not need
/// to import the `monero` package directly.
class MoneroPendingTx implements PendingTransaction {
  final MoneroPendingTransaction raw;

  MoneroPendingTx(this.raw);

  @override
  double get amount => doubleAmountFromInt(raw.amount());

  @override
  double get fee => doubleAmountFromInt(raw.fee());

  String get errorString => raw.errorString();
}
