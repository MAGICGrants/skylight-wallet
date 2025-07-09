import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:monero/monero.dart' as monero;

class HistoryTx {
  final String hash;
  final double amount;
  final int timestamp;
  final monero.TransactionInfo_Direction direction;

  HistoryTx({
    required this.hash,
    required this.amount,
    required this.timestamp,
    required this.direction,
  });
}

class WalletModel with ChangeNotifier {
  final monero.WalletManager _walletManager =
      monero.WalletManagerFactory_getWalletManager();

  late monero.wallet _wallet;

  monero.wallet get wallet => _wallet;

  void _connectToDaemon() {
    monero.Wallet_init(_wallet, daemonAddress: '192.168.255.114:18081');
    monero.Wallet_setTrustedDaemon(_wallet, arg: true);
    monero.Wallet_connectToDaemon(_wallet);
    monero.Wallet_refresh(_wallet);
    monero.Wallet_startRefresh(_wallet);
    monero.Wallet_refreshAsync(_wallet);
  }

  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, [
    String passphrase = '',
  ]) async {
    String path = (await getApplicationDocumentsDirectory()).path;
    path = '$path/wallet1111';
    final walletFile = File(path);

    if (await walletFile.exists()) {
      await walletFile.delete();
    }

    _wallet = monero.WalletManager_recoveryWallet(
      _walletManager,
      mnemonic: mnemonic,
      password: 'pass',
      path: path,
      restoreHeight: restoreHeight,
      seedOffset: passphrase,
    );

    _connectToDaemon();
    notifyListeners();
  }

  Future<void> openExistingWallet() async {
    String path = (await getApplicationDocumentsDirectory()).path;
    path = '$path/wallet11111111';
    _wallet = monero.WalletManager_openWallet(
      _walletManager,
      path: path,
      password: 'pass',
    );
    _connectToDaemon();
    notifyListeners();
  }

  bool isConnected() {
    return monero.Wallet_connected(_wallet) != 0;
  }

  bool isSynced() {
    return monero.Wallet_synchronized(_wallet);
  }

  String getAddress() {
    return monero.Wallet_address(_wallet, accountIndex: 0);
  }

  int getHeight() {
    return monero.Wallet_blockChainHeight(_wallet);
  }

  double getBalance() {
    return monero.Wallet_balance(_wallet, accountIndex: 0) / 1000000000000;
  }

  List<HistoryTx> getTransactionHistory() {
    const txHistSize = 100;
    final txHistPtr = monero.Wallet_history(_wallet);
    final txCount = monero.TransactionHistory_count(txHistPtr);
    final List<HistoryTx> txs = [];

    for (int i = 1; i <= txHistSize; i++) {
      final txIndex = txCount - i;
      if (txIndex < 0) break;

      final txPtr = monero.TransactionHistory_transaction(
        txHistPtr,
        index: txIndex,
      );

      final hash = monero.TransactionInfo_hash(txPtr);
      final amount = monero.TransactionInfo_amount(txPtr);
      final timestamp = monero.TransactionInfo_timestamp(txPtr);
      final height = monero.TransactionInfo_blockHeight(txPtr);
      final direction = monero.TransactionInfo_direction(txPtr);
      final fee = (direction == monero.TransactionInfo_Direction.Out)
          ? monero.TransactionInfo_fee(txPtr)
          : 0;

      final tx = HistoryTx(
        hash: hash,
        amount: (amount + fee) / 1000000000000,
        timestamp: timestamp,
        direction: direction,
      );

      txs.add(tx);
    }

    txs.sort((a, b) {
      return a.timestamp < b.timestamp ? 1 : -1;
    });

    return txs;
  }
}
