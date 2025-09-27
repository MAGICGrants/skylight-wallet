// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:monero_light_wallet/consts.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/services/tor_service.dart';
import 'package:monero_light_wallet/util/formatting.dart';
import 'package:monero_light_wallet/util/height.dart';
import 'package:monero_light_wallet/util/logging.dart';
import 'package:monero_light_wallet/util/wallet.dart';
import 'package:monero/monero.dart' as monero;
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
  final int? index;
  final int direction;
  final String hash;
  final double amount;
  final double fee;
  final List<TxRecipient> recipients;
  final int? accountIndex;
  final List<int> subaddrIndexList;
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
    required this.accountIndex,
    required this.subaddrIndexList,
    required this.timestamp,
    required this.height,
    required this.confirmations,
    required this.key,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'direction': direction,
    'hash': hash,
    'amount': amount,
    'fee': fee,
    'recipients': recipients.map((r) => r.toJson()).toList(),
    'accountIndex': accountIndex,
    'subaddrIndexList': subaddrIndexList,
    'timestamp': timestamp,
    'height': height,
    'confirmations': confirmations,
    'key': key,
  };

  factory TxDetails.fromJson(Map<String, dynamic> json) => TxDetails(
    index: json['index'] as int?,
    direction: json['direction'] as int,
    hash: json['hash'] as String,
    amount: (json['amount'] as num).toDouble(),
    fee: (json['fee'] as num).toDouble(),
    recipients: (json['recipients'] as List<dynamic>)
        .map((r) => TxRecipient.fromJson(r as Map<String, dynamic>))
        .toList(),
    accountIndex: json['accountIndex'] as int?,
    subaddrIndexList: (json['subaddrIndexList'] as List<dynamic>).cast<int>(),
    timestamp: json['timestamp'] as int,
    height: json['height'] as int,
    confirmations: json['confirmations'] as int,
    key: json['key'] as String,
  );
}

class TxRecipient {
  final String address;
  final double amount;

  TxRecipient(this.address, this.amount);

  Map<String, dynamic> toJson() => {'address': address, 'amount': amount};

  factory TxRecipient.fromJson(Map<String, dynamic> json) => TxRecipient(
    json['address'] as String,
    (json['amount'] as num).toDouble(),
  );
}

class LWSConnectionDetails {
  final String address;
  final String proxyPort;
  final bool useTor;
  final bool useSsl;

  LWSConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useTor,
    required this.useSsl,
  });
}

class WalletModel with ChangeNotifier {
  Timer? _connectionCheckTimer;
  Timer? _refreshTimer;

  final _w2WalletManager = Monero()
      .walletManagerFactory()
      .getLWSFWalletManager();

  late int _w2WalletManagerFfiAddr;

  late Wallet2Wallet _w2Wallet;
  late int _w2WalletFfiAddress;

  late Wallet2TransactionHistory _w2TxHistory;
  late int _w2TxHistoryFfiAddress;

  late String _connectionAddress;
  late String _connectionProxyPort;
  late bool _connectionUseTor;
  late bool _connectionUseSsl;

  var _isConnected = false;
  var _isSynced = false;
  int? _syncedHeight;
  double? _unlockedBalance;
  double? _totalBalance;
  List<TxDetails> _txHistory = [];

  bool get isConnected => _isConnected;
  bool get isSynced => _isSynced;
  int? get syncedHeight => _syncedHeight;
  double? get unlockedBalance => _unlockedBalance;
  double? get totalBalance => _totalBalance;
  List<TxDetails> get txHistory => _txHistory;

  WalletModel() {
    _w2WalletManagerFfiAddr = _w2WalletManager.ffiAddress();

    _startTimers();
  }

  void _startTimers() {
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _runCheckConnectionTimerTask();
    });

    _refreshTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      _runRefreshTimerTask();
    });
  }

  Future<void> _runCheckConnectionTimerTask() async {
    final isConnected = await getIsConnected();

    if (isConnected != _isConnected) {
      _isConnected = isConnected;

      if (isConnected) {
        refresh();
        await _loadTxHistory();
        await store();
      }

      notifyListeners();
    }
  }

  Future<void> _runRefreshTimerTask() async {
    await Future.wait([
      loadIsSynced(),
      loadSyncedHeight(),
      loadUnlockedBalance(),
      loadTotalBalance(),
      _loadTxHistory(),
    ]);

    notifyListeners();
  }

  Future<void> _loadTxHistory() async {
    final txCount = _w2TxHistory.count();

    if (txCount > _txHistory.length) {
      _txHistory = await _getFullTxHistory();
      await _persistTxHistoryCount();
    }
  }

  // Future<int> _getTxHistoryCount() async {
  //   return Isolate.run(
  //     // ignore: deprecated_member_use
  //     () => monero.TransactionHistory_count(
  //       Pointer<Void>.fromAddress(_w2TxHistoryFfiAddress),
  //     ),
  //   );
  // }

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
      SharedPreferencesKeys.connectionUseTor,
      _connectionUseTor,
    );
    await SharedPreferencesService.set(
      SharedPreferencesKeys.connectionUseSsl,
      _connectionUseSsl,
    );
  }

  Future<LWSConnectionDetails> getPersistedConnection() async {
    return LWSConnectionDetails(
      address:
          await SharedPreferencesService.get<String>(
            SharedPreferencesKeys.connectionAddress,
          ) ??
          '',
      proxyPort:
          await SharedPreferencesService.get<String>(
            SharedPreferencesKeys.connectionProxyPort,
          ) ??
          '',
      useTor:
          await SharedPreferencesService.get<bool>(
            SharedPreferencesKeys.connectionUseTor,
          ) ??
          false,
      useSsl:
          await SharedPreferencesService.get<bool>(
            SharedPreferencesKeys.connectionUseSsl,
          ) ??
          false,
    );
  }

  Future<void> loadPersistedConnection() async {
    final connectionDetails = await getPersistedConnection();
    setConnection(
      address: connectionDetails.address,
      proxyPort: connectionDetails.proxyPort,
      useTor: connectionDetails.useTor,
      useSsl: connectionDetails.useSsl,
    );
  }

  Future<void> _persistTxHistoryCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('txHistoryCount', _txHistory.length);
  }

  Future<int> getPersistedTxHistoryCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('txHistoryCount') ?? 0;
  }

  void setConnection({
    required String address,
    required String proxyPort,
    required bool useTor,
    required bool useSsl,
  }) {
    _connectionAddress = address;
    _connectionProxyPort = proxyPort;
    _connectionUseTor = useTor;
    _connectionUseSsl = useSsl;
    notifyListeners();
  }

  Future<void> connectToDaemon() async {
    String? torProxyPort;

    if (_connectionUseTor) {
      torProxyPort = TorService.sharedInstance.getProxyInfo().port.toString();
    }

    final proxyPort = torProxyPort ?? _connectionProxyPort;

    _w2Wallet.init(
      daemonAddress: _connectionAddress,
      proxyAddress: proxyPort != '' ? '127.0.0.1:$proxyPort' : '',
      useSsl: _connectionUseSsl,
      lightWallet: true,
    );

    _w2Wallet.connectToDaemon();
  }

  void refresh() {
    _w2Wallet.startRefresh();
    _w2Wallet.refresh();
    _w2TxHistory.refresh();
  }

  Future<String> create() async {
    // ignore: deprecated_member_use
    final polyseed = await Isolate.run(() => monero.Wallet_createPolyseed());
    final currentHeight = await getCurrentBlockchainHeight();
    await restoreFromMnemonic(polyseed, currentHeight);
    refresh();
    await connectToDaemon();
    store();

    return polyseed;
  }

  Future<int> getCurrentHeight() {
    final wmFfiAddr = _w2WalletManager.ffiAddress();

    return Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_blockchainHeight(
        Pointer.fromAddress(wmFfiAddr),
      );
    });
  }

  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, [
    String passphrase = '',
  ]) async {
    final wmFfiAddr = _w2WalletManager.ffiAddress();

    final legacyWalletPtr = Pointer<Void>.fromAddress(
      await Isolate.run(() {
        // ignore: deprecated_member_use
        return monero.WalletManager_recoveryWallet(
          Pointer.fromAddress(wmFfiAddr),
          mnemonic: mnemonic,
          password: 'pass',
          path: '',
          restoreHeight: restoreHeight,
          seedOffset: passphrase,
        ).address;
      }),
    );

    final legacyWallet = MoneroWallet(legacyWalletPtr);

    final polyseedWalletPtr = Pointer<Void>.fromAddress(
      await Isolate.run(() {
        // ignore: deprecated_member_use
        return monero.WalletManager_createWalletFromPolyseed(
          Pointer.fromAddress(wmFfiAddr),
          path: '',
          password: 'pass',
          mnemonic: mnemonic,
          seedOffset: '',
          newWallet: true,
          restoreHeight: restoreHeight,
          kdfRounds: 1,
        ).address;
      }),
    );

    final polyseedWallet = MoneroWallet(polyseedWalletPtr);

    final legacyError = legacyWallet.errorString();
    final polyseedError = polyseedWallet.errorString();

    final walletPath = await getWalletPath();

    if (!legacyError.contains('word list failed verification')) {
      final walletPtr = Pointer<Void>.fromAddress(
        await Isolate.run(() {
          // ignore: deprecated_member_use
          return monero.WalletManager_recoveryWallet(
            Pointer.fromAddress(wmFfiAddr),
            mnemonic: mnemonic,
            password: 'pass',
            path: walletPath,
            restoreHeight: restoreHeight,
            seedOffset: passphrase,
          ).address;
        }),
      );

      _w2Wallet = MoneroWallet(walletPtr);
    } else if (polyseedError != 'Failed polyseed decode') {
      final walletPtr = Pointer<Void>.fromAddress(
        await Isolate.run(() {
          // ignore: deprecated_member_use
          return monero.WalletManager_createWalletFromPolyseed(
            Pointer.fromAddress(wmFfiAddr),
            path: walletPath,
            password: 'pass',
            mnemonic: mnemonic,
            seedOffset: passphrase,
            newWallet: true,
            restoreHeight: restoreHeight,
            kdfRounds: 1,
          ).address;
        }),
      );

      _w2Wallet = MoneroWallet(walletPtr);
    }

    _w2WalletFfiAddress = _w2Wallet.ffiAddress();

    _w2TxHistory = MoneroTransactionHistory(
      Pointer<Void>.fromAddress(
        await Isolate.run(
          // ignore: deprecated_member_use
          () => monero.Wallet_history(
            Pointer<Void>.fromAddress(_w2WalletFfiAddress),
          ).address,
        ),
      ),
    );

    _w2TxHistoryFfiAddress = _w2TxHistory.ffiAddress();

    store();
    notifyListeners();
  }

  Future openExisting() async {
    final path = await getWalletPath();

    _w2Wallet = _w2WalletManager.openWallet(path: path, password: 'pass');
    final errorString = _w2WalletManager.errorString();

    if (errorString != '') {
      log(LogLevel.error, 'Failed to open existing wallet: $errorString');
    }

    _w2TxHistory = _w2Wallet.history();

    notifyListeners();
  }

  Future<bool> store() async {
    final walletFfiAddr = _w2Wallet.ffiAddress();
    return Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_store(Pointer<Void>.fromAddress(walletFfiAddr)),
    );
  }

  Future delete() async {
    _w2WalletManager.closeWallet(_w2Wallet, false);
    final path = await getWalletPath();
    final walletFile = File(path);
    await walletFile.delete();

    final prefs = await SharedPreferences.getInstance();
    prefs.remove('txHistoryCount');
  }

  Future<bool> hasExistingWallet() async {
    final exists = _w2WalletManager.walletExists(await getWalletPath());
    final errorString = _w2WalletManager.errorString();

    if (errorString != '') {
      log(LogLevel.error, 'Failed to check if wallet exists: $errorString');
    }

    return exists;
  }

  Future<bool> getIsConnected() async {
    final w2WalletFfiAddr = _w2Wallet.ffiAddress();

    final connected = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connected(Pointer<Void>.fromAddress(w2WalletFfiAddr)),
    );

    return connected != 0;
  }

  Future<void> loadIsSynced() async {
    _isSynced = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_synchronized(
        Pointer<Void>.fromAddress(_w2WalletFfiAddress),
      ),
    );
  }

  Future<void> loadSyncedHeight() async {
    _syncedHeight = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_blockChainHeight(
        Pointer<Void>.fromAddress(_w2WalletFfiAddress),
      ),
    );
  }

  Future<void> loadTotalBalance() async {
    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_balance(
        Pointer<Void>.fromAddress(_w2WalletFfiAddress),
        accountIndex: 0,
      ),
    );

    _totalBalance = doubleAmountFromInt(amount);
  }

  Future<void> loadUnlockedBalance() async {
    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_unlockedBalance(
        Pointer<Void>.fromAddress(_w2WalletFfiAddress),
        accountIndex: 0,
      ),
    );

    _unlockedBalance = doubleAmountFromInt(amount);
  }

  String getPrimaryAddress() {
    return _w2Wallet.address(accountIndex: 0);
  }

  Future<String> getUnusedSubaddress() async {
    final txHistory = await _getFullTxHistory();

    Set<int> usedIndexes = {};

    for (final tx in txHistory) {
      if (tx.accountIndex == 0) {
        for (final subaddrIndex in tx.subaddrIndexList) {
          usedIndexes.add(subaddrIndex);
        }
      }
    }

    int nextSubaddrIndex = 1;

    while (usedIndexes.contains(nextSubaddrIndex)) {
      nextSubaddrIndex++;
    }

    return _w2Wallet.address(accountIndex: 0, addressIndex: nextSubaddrIndex);
  }

  Future<MoneroPendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll,
  ) async {
    final amountInt = _w2Wallet.amountFromDouble(amount);
    final w2WalletFfiAddr = _w2Wallet.ffiAddress();

    final txPointer = Pointer<Void>.fromAddress(
      await Isolate.run(() {
        // ignore: deprecated_member_use
        return monero.Wallet_createTransactionMultDest(
          Pointer.fromAddress(w2WalletFfiAddr),
          isSweepAll: isSweepAll,
          dstAddr: [destinationAddress],
          amounts: [amountInt],
          mixinCount: 15,
          pendingTransactionPriority: 0,
          subaddr_account: 0,
        ).address;
      }),
    );

    return MoneroPendingTransaction(txPointer);
  }

  Future<void> commitTx(
    MoneroPendingTransaction tx,
    String destinationAddress,
  ) async {
    final txFfiAddr = tx.ffiAddress();

    await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.PendingTransaction_commit(
        Pointer.fromAddress(txFfiAddr),
        filename: '',
        overwrite: false,
      );
    });

    final errorMsg = tx.errorString();

    if (errorMsg != '' && errorMsg != 'Schema expected string') {
      log(LogLevel.error, 'Failed to commit transaction');
      log(LogLevel.error, errorMsg);
      throw FormatException(errorMsg);
    }

    final recipient = TxRecipient(
      destinationAddress,
      doubleAmountFromInt(tx.amount()),
    );

    final TxDetails txDetails = TxDetails(
      index: null,
      direction: txDirectionOutgoing,
      hash: tx.txid(''),
      amount: doubleAmountFromInt(tx.amount()),
      fee: doubleAmountFromInt(tx.fee()),
      recipients: [recipient],
      accountIndex: 0,
      subaddrIndexList: [],
      timestamp: (DateTime.now().millisecondsSinceEpoch / 1000).round(),
      height: 0,
      confirmations: 0,
      key: _w2Wallet.getTxKey(txid: tx.txid('')),
    );

    await addPendingTx(txDetails);

    store();
    refresh();
  }

  String resolveOpenAlias(String address) {
    return _w2WalletManager.resolveOpenAlias(
      address: address,
      dnssecValid: true,
    );
  }

  Future<void> addPendingTx(TxDetails tx) async {
    final pendingTxs = await _getPendingTxs();
    pendingTxs.add(tx);
    _persistPendingTxs(pendingTxs);
  }

  Future<void> _removePendingTx(String hash) async {
    final pendingTxs = await _getPendingTxs();
    pendingTxs.removeWhere((tx) => tx.hash == hash);
    _persistPendingTxs(pendingTxs);
  }

  Future<void> _persistPendingTxs(List<TxDetails> pendingTxs) async {
    final prefs = await SharedPreferences.getInstance();
    final txsJson = pendingTxs.map((tx) => json.encode(tx)).toList();
    await prefs.setStringList('pendingTxs', txsJson);
  }

  Future<List<TxDetails>> _getPendingTxs() async {
    final prefs = await SharedPreferences.getInstance();
    final txsJson = prefs.getStringList('pendingTxs') ?? [];

    final pendingTxs = txsJson
        .map(
          (jsonString) => TxDetails.fromJson(
            json.decode(jsonString) as Map<String, dynamic>,
          ),
        )
        .toList();

    return pendingTxs;
  }

  List<TxDetails> getConfirmedTxHistory() {
    final txCount = _w2TxHistory.count();
    final List<TxDetails> confirmedTxs = [];

    for (int i = 0; i < txCount; i++) {
      final tx = getTxDetails(i);
      confirmedTxs.add(tx);
    }

    confirmedTxs.sort((a, b) {
      return a.timestamp < b.timestamp ? 1 : -1;
    });

    return confirmedTxs;
  }

  Future<List<TxDetails>> _getFullTxHistory() async {
    final pendingTxs = await _getPendingTxs();
    final confirmedTxHistory = getConfirmedTxHistory();

    final confirmedTxMap = {for (var tx in confirmedTxHistory) tx.hash: tx};
    final fullTxHistory = <TxDetails>[];

    fullTxHistory.addAll(confirmedTxHistory);

    for (final pendingTx in pendingTxs) {
      if (confirmedTxMap.containsKey(pendingTx.hash)) {
        _removePendingTx(pendingTx.hash);
      } else {
        fullTxHistory.add(pendingTx);
      }
    }

    fullTxHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return fullTxHistory;
  }

  TxDetails getTxDetails(int txIndex) {
    final tx = _w2TxHistory.transaction(txIndex);
    final direction = tx.direction();
    final hash = tx.hash();
    final amountSent = doubleAmountFromInt(tx.amount());
    final fee = doubleAmountFromInt(tx.fee());
    final timestamp = tx.timestamp();
    final height = tx.blockHeight();
    final confirmations = _w2Wallet.blockChainHeight() - height + 1;
    final key = _w2Wallet.getTxKey(txid: hash);

    List<TxRecipient> recipients = [];
    final recipientsCount = tx.transfers_count();
    final accountIndex = tx.subaddrAccount();
    final subaddrIndexList = tx
        .subaddrIndex()
        .split(", ")
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

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
      accountIndex: accountIndex,
      subaddrIndexList: subaddrIndexList,
      timestamp: timestamp,
      height: height,
      confirmations: confirmations,
      key: key,
    );
  }
}
