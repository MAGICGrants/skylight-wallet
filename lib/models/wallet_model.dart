// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/util/formatting.dart';
import 'package:monero_light_wallet/util/wallet.dart';
import 'package:monero/src/monero.dart';
import 'package:monero/src/wallet2.dart';
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
  final int direction;
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

class LWSConnectionDetails {
  final String address;
  final String proxyPort;
  final bool useSsl;

  LWSConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useSsl,
  });
}

class WalletModel with ChangeNotifier {
  final _walletManager = Monero().walletManagerFactory().getLWSFWalletManager();

  late Wallet2Wallet _wallet;
  // late monero.Coins _coinsPtr;
  late Wallet2TransactionHistory _txHistory;
  late String _connectionAddress;
  late String _connectionProxyPort;
  late bool _connectionUseSsl;

  Wallet2Wallet get wallet => _wallet;

  Future<void> persistCurrentConnection() async {
    await SharedPreferencesService.set(
      SharedPreferencesKeys.connectionAddress,
      _connectionAddress,
    );
    await SharedPreferencesService.set(
      SharedPreferencesKeys.connectionProxyPort,
      _connectionProxyPort,
    );
    await SharedPreferencesService.set(
      SharedPreferencesKeys.connectionUseSsl,
      _connectionUseSsl,
    );
  }

  Future<LWSConnectionDetails> getPersistedConnection() async {
    return LWSConnectionDetails(
      address:
          await SharedPreferencesService.get(
            SharedPreferencesKeys.connectionAddress,
          ) ??
          '',
      proxyPort:
          await SharedPreferencesService.get(
            SharedPreferencesKeys.connectionProxyPort,
          ) ??
          '',
      useSsl:
          await SharedPreferencesService.get(
            SharedPreferencesKeys.connectionUseSsl,
          ) ??
          false,
    );
  }

  Future<void> loadPersistedConnection() async {
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
    return _txHistory.count();
  }

  void setConnection(String address, String proxyPort, bool useSsl) {
    _connectionAddress = address;
    _connectionProxyPort = proxyPort;
    _connectionUseSsl = useSsl;
    notifyListeners();
  }

  void connectToDaemon() {
    _wallet.init(
      daemonAddress: _connectionAddress,
      proxyAddress: _connectionProxyPort != ''
          ? '127.0.0.1:$_connectionProxyPort'
          : '',
      useSsl: _connectionUseSsl,
      lightWallet: true,
    );
    _wallet.connectToDaemon();
  }

  void refresh() {
    _wallet.startRefresh();
    _wallet.refresh();
    // monero.Coins_refresh(_coinsPtr);
    _txHistory.refresh();
  }

  String generatePolyseed() {
    return _wallet.createPolyseed();
  }

  Future<int> getCurrentHeight() {
    return _walletManager.blockchainHeight();
  }

  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, [
    String passphrase = '',
  ]) async {
    final path = await getWalletPath();

    _wallet = _walletManager.recoveryWallet(
      mnemonic: mnemonic,
      password: 'pass',
      path: path,
      restoreHeight: restoreHeight,
      seedOffset: passphrase,
    );

    // _coinsPtr = monero.Wallet_coins(_walletPtr);
    _txHistory = wallet.history();

    store();
    notifyListeners();
  }

  Future openExisting() async {
    final path = await getWalletPath();

    _wallet = _walletManager.openWallet(path: path, password: 'pass');
    // _coinsPtr = monero.Wallet_coins(_walletPtr);
    _txHistory = _wallet.history();

    notifyListeners();
  }

  void store() {
    _wallet.store();
  }

  Future delete() async {
    _walletManager.closeWallet(_wallet, false);
    final path = await getWalletPath();
    final walletFile = File(path);
    await walletFile.delete();

    final prefs = await SharedPreferences.getInstance();
    prefs.remove('txHistoryCount');
  }

  Future<bool> hasExistingWallet() async {
    return _walletManager.walletExists(await getWalletPath());
  }

  bool isConnected() {
    return _wallet.connected() != 0;
  }

  bool isSynced() {
    return _wallet.synchronized();
  }

  String getAddress() {
    return _wallet.address(accountIndex: 0);
  }

  int getSyncedHeight() {
    return _wallet.blockChainHeight();
  }

  double getBalance() {
    return doubleAmountFromInt(_wallet.balance(accountIndex: 0));
  }

  void send(String destinationAddress, double amount) {
    final amountInt = _wallet.amountFromDouble(amount);

    final tx = _wallet.createTransaction(
      dst_addr: destinationAddress,
      payment_id: '',
      amount: amountInt,
      mixin_count: 15,
      pendingTransactionPriority: 0,
      subaddr_account: 0,
    );

    tx.commit(filename: '', overwrite: false);
    store();
    refresh();
  }

  String resolveOpenAlias(String address) {
    return _walletManager.resolveOpenAlias(address: address, dnssecValid: true);
  }

  List<TxDetails> getTransactionHistory() {
    const txHistSize = 100;
    final txCount = _txHistory.count();
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
    final tx = _txHistory.transaction(txIndex);
    final direction = tx.direction();
    final hash = tx.hash();
    final amountSent = doubleAmountFromInt(tx.amount());
    final fee = doubleAmountFromInt(tx.fee());
    final timestamp = tx.timestamp();
    final height = tx.blockHeight();
    final confirmations = _wallet.blockChainHeight() - height;
    final key = _wallet.getTxKey(txid: hash);

    List<TxRecipient> recipients = [];
    final recipientsCount = tx.transfers_count();

    for (int i = 0; i < recipientsCount; i++) {
      final address = tx.transfers_address(i);
      final amountInt = tx.transfers_amount(i);
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
