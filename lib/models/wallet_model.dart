import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:monero_light_wallet/util/formatting.dart';
import 'package:monero_light_wallet/util/wallet.dart';
import 'package:monero/monero.dart' as monero;
import 'package:shared_preferences/shared_preferences.dart';

String generateHexString(int length) {
  final Random random = Random.secure();
  final Uint8List bytes = Uint8List(length);

  for (int i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }

  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

class TxDetails {
  final int index;
  final monero.TransactionInfo_Direction direction;
  final String hash;
  final double amount;
  final double fee;
  final List<TxRecipient> recipients;
  final int timestamp;
  final int height;
  final int confirmations;
  final String key;

  TxDetails({
    required this.index,
    required this.direction,
    required this.hash,
    required this.amount,
    required this.fee,
    required this.recipients,
    required this.timestamp,
    required this.height,
    required this.confirmations,
    required this.key,
  });
}

class TxRecipient {
  final String address;
  final double amount;

  TxRecipient(this.address, this.amount);
}

class DaemonConnectionDetails {
  final String address;
  final String proxyPort;
  final bool useSsl;

  DaemonConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useSsl,
  });
}

class WalletModel with ChangeNotifier {
  final monero.WalletManager _walletManagerPtr =
      monero.WalletManagerFactory_getWalletManager();

  late monero.wallet _walletPtr;
  late monero.Coins _coinsPtr;
  late monero.TransactionHistory _txHistoryPtr;
  late String _connectionAddress;
  late String _connectionProxyPort;
  late bool _connectionUseSsl;

  monero.wallet get wallet => _walletPtr;

  Future persistCurrentConnection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('connectionAddress', _connectionAddress);
    prefs.setString('connectionProxyPort', _connectionProxyPort);
    prefs.setBool('connectionUseSsl', _connectionUseSsl);
  }

  Future<DaemonConnectionDetails> getPersistedConnection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return DaemonConnectionDetails(
      address: prefs.getString('connectionAddress') ?? '',
      proxyPort: prefs.getString('connectionProxyPort') ?? '',
      useSsl: prefs.getBool('connectionUseSsl') ?? false,
    );
  }

  Future loadPersistedConnection() async {
    final connectionDetails = await getPersistedConnection();
    setConnection(
      connectionDetails.address,
      connectionDetails.proxyPort,
      connectionDetails.useSsl,
    );
  }

  Future persistTxHistoryCount() async {
    final count = await getTxHistoryCount();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('txHistoryCount', count);
  }

  Future<int> getPersistedTxHistoryCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('txHistoryCount') ?? 0;
  }

  Future<int> getTxHistoryCount() async {
    return monero.TransactionHistory_count(_txHistoryPtr);
  }

  void setConnection(String address, String proxyPort, bool useSsl) {
    _connectionAddress = address;
    _connectionProxyPort = proxyPort;
    _connectionUseSsl = useSsl;
    notifyListeners();
  }

  void connectToDaemon() {
    monero.Wallet_init(
      _walletPtr,
      daemonAddress: _connectionAddress,
      proxyAddress: _connectionProxyPort != ''
          ? '127.0.0.1:$_connectionProxyPort'
          : '',
      useSsl: _connectionUseSsl,
    );
    monero.Wallet_setTrustedDaemon(_walletPtr, arg: true);
    monero.Wallet_connectToDaemon(_walletPtr);
  }

  void refresh() {
    monero.Wallet_startRefresh(_walletPtr);
    monero.Wallet_refresh(_walletPtr);
    monero.Coins_refresh(_coinsPtr);
    monero.TransactionHistory_refresh(_txHistoryPtr);
  }

  String generatePolyseed() {
    return monero.Wallet_createPolyseed();
  }

  int getCurrentHeight() {
    return monero.WalletManager_blockchainHeight(_walletManagerPtr);
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

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('txHistoryCount');
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

  int getSyncedHeight() {
    return monero.Wallet_blockChainHeight(_walletPtr);
  }

  double getBalance() {
    return doubleAmountFromInt(
      monero.Wallet_balance(_walletPtr, accountIndex: 0),
    );
  }

  void send(String destinationAddress, double amount) {
    final paymentId = generateHexString(32);
    final amountInt = monero.Wallet_amountFromDouble(amount);

    final txPtr = monero.Wallet_createTransaction(
      _walletPtr,
      dst_addr: destinationAddress,
      payment_id: paymentId,
      amount: amountInt,
      mixin_count: 10,
      pendingTransactionPriority: 0,
      subaddr_account: 0,
    );

    monero.PendingTransaction_commit(txPtr, filename: '', overwrite: false);
    store();
    refresh();
  }

  String resolveOpenAlias(String address) {
    return monero.WalletManager_resolveOpenAlias(
      _walletManagerPtr,
      address: address,
      dnssecValid: true,
    );
  }

  List<TxDetails> getTransactionHistory() {
    const txHistSize = 100;
    final txHistPtr = monero.Wallet_history(_walletPtr);
    final txCount = monero.TransactionHistory_count(txHistPtr);
    final List<TxDetails> txs = [];

    for (int i = 1; i <= txHistSize; i++) {
      final txIndex = txCount - i;
      if (txIndex < 0) break;
      final tx = getTxDetails(txIndex);
      txs.add(tx);
    }

    txs.sort((a, b) {
      return a.timestamp < b.timestamp ? 1 : -1;
    });

    return txs;
  }

  TxDetails getTxDetails(int txIndex) {
    final txHistPtr = monero.Wallet_history(_walletPtr);

    final txInfoPtr = monero.TransactionHistory_transaction(
      txHistPtr,
      index: txIndex,
    );

    final direction = monero.TransactionInfo_direction(txInfoPtr);
    final hash = monero.TransactionInfo_hash(txInfoPtr);
    final amountSent = doubleAmountFromInt(
      monero.TransactionInfo_amount(txInfoPtr),
    );
    final fee = doubleAmountFromInt(monero.TransactionInfo_fee(txInfoPtr));
    final timestamp = monero.TransactionInfo_timestamp(txInfoPtr);
    final height = monero.TransactionInfo_blockHeight(txInfoPtr);
    final confirmations = monero.Wallet_blockChainHeight(_walletPtr) - height;
    final key = monero.Wallet_getTxKey(_walletPtr, txid: hash);

    List<TxRecipient> recipients = [];
    final recipientsCount = monero.TransactionInfo_transfers_count(txInfoPtr);

    for (int i = 0; i < recipientsCount; i++) {
      final address = monero.TransactionInfo_transfers_address(txInfoPtr, i);
      final amountInt = monero.TransactionInfo_transfers_amount(txInfoPtr, i);
      final amount = doubleAmountFromInt(amountInt);
      recipients.add(TxRecipient(address, amount));
    }

    return TxDetails(
      index: txIndex,
      direction: direction,
      hash: hash,
      amount: amountSent,
      fee: fee,
      recipients: recipients,
      timestamp: timestamp,
      height: height,
      confirmations: confirmations,
      key: key,
    );
  }
}
