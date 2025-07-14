import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:monero_light_wallet/util/wallet.dart';
import 'package:monero/monero.dart' as monero;

String generateHexString(int length) {
  final Random random = Random.secure();
  final Uint8List bytes = Uint8List(length);

  for (int i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }

  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

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
  final monero.WalletManager _walletManagerPtr =
      monero.WalletManagerFactory_getWalletManager();

  late monero.wallet _walletPtr;
  late monero.Coins _coinsPtr;
  late monero.TransactionHistory _txHistoryPtr;

  monero.wallet get wallet => _walletPtr;

  void _connectToDaemon() {
    monero.Wallet_init(_walletPtr, daemonAddress: '192.168.255.114:18081');
    monero.Wallet_setTrustedDaemon(_walletPtr, arg: true);
    monero.Wallet_connectToDaemon(_walletPtr);
  }

  void refresh() {
    monero.Wallet_startRefresh(_walletPtr);
    monero.Wallet_refresh(_walletPtr);
    monero.Coins_refresh(_coinsPtr);
    monero.TransactionHistory_refresh(_txHistoryPtr);
  }

  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, [
    String passphrase = '',
  ]) async {
    final path = await getWalletPath();

    _walletPtr = monero.WalletManager_recoveryWallet(
      _walletManagerPtr,
      mnemonic: mnemonic,
      password: 'pass',
      path: path,
      restoreHeight: restoreHeight,
      seedOffset: passphrase,
    );

    _coinsPtr = monero.Wallet_coins(_walletPtr);
    _txHistoryPtr = monero.Wallet_history(_walletPtr);

    store();
    refresh();
    _connectToDaemon();
    notifyListeners();
  }

  Future openExisting() async {
    final path = await getWalletPath();

    _walletPtr = monero.WalletManager_openWallet(
      _walletManagerPtr,
      path: path,
      password: 'pass',
    );

    _coinsPtr = monero.Wallet_coins(_walletPtr);
    _txHistoryPtr = monero.Wallet_history(_walletPtr);

    _connectToDaemon();
    refresh();
    notifyListeners();
  }

  void store() {
    monero.Wallet_store(_walletPtr);
  }

  Future delete() async {
    monero.WalletManager_closeWallet(_walletManagerPtr, _walletPtr, false);
    final path = await getWalletPath();
    final walletFile = File(path);
    final walletKeysFile = File('$path.keys');
    await walletFile.delete();
    await walletKeysFile.delete();
  }

  Future<bool> hasExistingWallet() async {
    return monero.WalletManager_walletExists(
      _walletManagerPtr,
      await getWalletPath(),
    );
  }

  bool isConnected() {
    return monero.Wallet_connected(_walletPtr) != 0;
  }

  bool isSynced() {
    return monero.Wallet_synchronized(_walletPtr);
  }

  String getAddress() {
    return monero.Wallet_address(_walletPtr, accountIndex: 0);
  }

  int getHeight() {
    return monero.Wallet_blockChainHeight(_walletPtr);
  }

  double getBalance() {
    return monero.Wallet_balance(_walletPtr, accountIndex: 0) / 1000000000000;
  }

  void send(String destinationAddress, double amount) {
    final paymentId = generateHexString(32);
    final amountInt = monero.Wallet_amountFromDouble(amount);

    final tx = monero.Wallet_createTransaction(
      _walletPtr,
      dst_addr: destinationAddress,
      payment_id: paymentId,
      amount: amountInt,
      mixin_count: 10,
      pendingTransactionPriority: 0,
      subaddr_account: 0,
    );

    monero.PendingTransaction_commit(tx, filename: '', overwrite: true);
    refresh();
  }

  List<HistoryTx> getTransactionHistory() {
    const txHistSize = 100;
    final txHistPtr = monero.Wallet_history(_walletPtr);
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
