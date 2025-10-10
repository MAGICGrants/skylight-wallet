// ignore_for_file: implementation_imports

// import 'dart:async';
// import 'dart:async' show Timer;
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/monero.dart';
import 'package:monero/src/wallet2.dart';

import 'package:monero_light_wallet/consts.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/services/tor_service.dart';
import 'package:monero_light_wallet/util/formatting.dart';
import 'package:monero_light_wallet/util/height.dart';
import 'package:monero_light_wallet/util/logging.dart';
import 'package:monero_light_wallet/util/wallet.dart';
import 'package:monero_light_wallet/util/wallet_password.dart';

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
  final _w2WalletManager = Monero()
      .walletManagerFactory()
      .getLWSFWalletManager();

  Wallet2Wallet? _w2Wallet;

  Wallet2TransactionHistory? _w2TxHistory;

  late String _connectionAddress;
  late String _connectionProxyPort;
  late bool _connectionUseTor;
  late bool _connectionUseSsl;

  var _hasAttemptedConnection = false;
  var _isConnected = false;
  var _isSynced = false;
  int? _syncedHeight;
  double? _unlockedBalance;
  double? _totalBalance;
  List<TxDetails> _txHistory = [];

  Wallet2Wallet? get w2Wallet => _w2Wallet;
  bool get hasAttemptedConnection => _hasAttemptedConnection;
  bool get isConnected => _isConnected;
  bool get isSynced => _isSynced;
  int? get syncedHeight => _syncedHeight;
  double? get unlockedBalance => _unlockedBalance;
  double? get totalBalance => _totalBalance;
  List<TxDetails> get txHistory => _txHistory;
  bool get usingTor => _connectionUseTor;

  WalletModel() {
    _startTimers();
  }

  void notifyListenersFromOutside() {
    notifyListeners();
  }

  void _startTimers() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      _runCheckConnectionTimerTask();
    });

    Timer.periodic(Duration(seconds: 20), (timer) {
      _runRefreshTimerTask();
    });
  }

  Future<void> _runCheckConnectionTimerTask() async {
    if (_w2Wallet == null) {
      return;
    }

    final isConnected = await getIsConnected();

    if (isConnected != _isConnected) {
      _isConnected = isConnected;
      notifyListeners();
    }
  }

  Future<void> _runRefreshTimerTask() async {
    if (_w2Wallet == null) {
      return;
    }

    await refresh();
    await loadAllStats().timeout(Duration(seconds: 20));

    final txCount = _w2TxHistory!.count();

    if (_isConnected && _isSynced && txCount > 0) {
      await store();
    }
  }

  Future<void> loadAllStats() async {
    await Future.wait([
      loadIsSynced(),
      loadSyncedHeight(),
      loadUnlockedBalance(),
      loadTotalBalance(),
      loadTxHistory(),
    ]);

    notifyListeners();
  }

  Future<void> loadTxHistory({bool persistCount = true}) async {
    final txCount = _w2TxHistory!.count();
    var hasPendingTx = false;
    final pendingOutgoingTxs = await _getPendingOutgoingTxs();

    if (pendingOutgoingTxs.isNotEmpty) {
      hasPendingTx = true;
    } else if (_txHistory.isNotEmpty) {
      final lastTx = txHistory[0];

      if (lastTx.confirmations < 10) {
        hasPendingTx = true;
      }
    }

    if (txCount > _txHistory.length || hasPendingTx) {
      _txHistory = await _getFullTxHistory();

      if (persistCount) {
        await persistTxHistoryCount();
      }
    }
  }

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

  Future<void> persistTxHistoryCount() async {
    if (_txHistory.isEmpty) {
      return;
    }

    await SharedPreferencesService.set<int>(
      SharedPreferencesKeys.txHistoryCount,
      _txHistory.length,
    );
  }

  Future<int> getPersistedTxHistoryCount() async {
    return await SharedPreferencesService.get<int>(
          SharedPreferencesKeys.txHistoryCount,
        ) ??
        0;
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
    if (_w2Wallet == null) throw Exception("w2wallet is null");

    String? torProxyPort;

    if (_connectionUseTor) {
      await TorService.sharedInstance.waitUntilConnected();
      torProxyPort = TorService.sharedInstance.getProxyInfo().port.toString();
    }

    final proxyPort = torProxyPort ?? _connectionProxyPort;

    await _connectToDaemon(
      address: _connectionAddress,
      proxyPort: proxyPort,
      useSsl: _connectionUseSsl,
    );

    _hasAttemptedConnection = true;

    notifyListeners();
  }

  Future<void> _connectToDaemon({
    required String address,
    String? proxyPort,
    bool useSsl = false,
  }) async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final proxyAddress = proxyPort != '' ? '127.0.0.1:$proxyPort' : '';

    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_init(
        Pointer.fromAddress(walletFfiAddr),
        daemonAddress: '${useSsl ? 'https://' : 'http://'}$address',
        proxyAddress: proxyAddress,
        useSsl: useSsl,
        lightWallet: true,
      ),
    );

    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connectToDaemon(Pointer.fromAddress(walletFfiAddr)),
    );

    final connectError = _w2Wallet!.errorString();

    if (connectError != '') {
      log(LogLevel.warn, connectError);
    }
  }

  Future<void> refresh() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final historyFfiAddr = _w2TxHistory!.ffiAddress();

    await Future.wait([
      Isolate.run(
        // ignore: deprecated_member_use
        () => monero.Wallet_startRefresh(Pointer.fromAddress(walletFfiAddr)),
      ),
      Isolate.run(
        // ignore: deprecated_member_use
        () => monero.Wallet_refresh(Pointer.fromAddress(walletFfiAddr)),
      ),
      Isolate.run(
        // ignore: deprecated_member_use
        () => monero.TransactionHistory_refresh(
          Pointer.fromAddress(historyFfiAddr),
        ),
      ),
    ]);
  }

  Future<String> create() async {
    // ignore: deprecated_member_use
    final polyseed = await Isolate.run(() => monero.Wallet_createPolyseed());
    final currentHeight = await getCurrentBlockchainHeight();
    await restoreFromMnemonic(polyseed, currentHeight);
    await SharedPreferencesService.set<int>(
      SharedPreferencesKeys.walletRestoreHeight,
      currentHeight,
    );
    await refresh();
    await connectToDaemon();
    await store();

    return polyseed;
  }

  Future<int> getRestoreHeight() async {
    var w2RestoreHeight = _w2Wallet!.getRefreshFromBlockHeight();

    if (w2RestoreHeight > 0) {
      return w2RestoreHeight;
    }

    return await SharedPreferencesService.get<int>(
          SharedPreferencesKeys.walletRestoreHeight,
        ) ??
        0;
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

  Future<MoneroWallet> _getWalletFromLegacySeed({
    required String mnemonic,
    required int restoreHeight,
    required String password,
    bool isDummy = false,
  }) async {
    if (!isDummy && password == '') {
      throw Exception('Password should not be empty.');
    }

    final wmFfiAddr = _w2WalletManager.ffiAddress();
    final walletPath = await getWalletPath();

    final walletFfiAddr = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_recoveryWallet(
        Pointer.fromAddress(wmFfiAddr),
        mnemonic: mnemonic,
        seedOffset: '',
        restoreHeight: restoreHeight,
        password: password,
        path: isDummy ? '' : walletPath,
      ).address;
    });

    return MoneroWallet(Pointer<Void>.fromAddress(walletFfiAddr));
  }

  Future<MoneroWallet> _getWalletFromPolyseed({
    required String mnemonic,
    required int restoreHeight,
    required String password,
    bool isDummy = false,
  }) async {
    if (!isDummy && password == '') {
      throw Exception('Password should not be empty.');
    }

    final wmFfiAddr = _w2WalletManager.ffiAddress();
    final walletPath = await getWalletPath();

    final walletFfiAddr = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_createWalletFromPolyseed(
        Pointer.fromAddress(wmFfiAddr),
        mnemonic: mnemonic,
        seedOffset: '',
        restoreHeight: restoreHeight,
        path: isDummy ? '' : walletPath,
        password: password,
        newWallet: true,
        kdfRounds: 1,
      ).address;
    });

    return MoneroWallet(Pointer<Void>.fromAddress(walletFfiAddr));
  }

  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, [
    String passphrase = '',
  ]) async {
    final legacyWallet = await _getWalletFromLegacySeed(
      mnemonic: mnemonic,
      restoreHeight: restoreHeight,
      password: '',
      isDummy: true,
    );

    final polyseedWallet = await _getWalletFromPolyseed(
      mnemonic: mnemonic,
      restoreHeight: restoreHeight,
      password: '',
      isDummy: true,
    );

    final legacyError = legacyWallet.errorString();
    final polyseedError = polyseedWallet.errorString();

    final walletPassword = genWalletPassword();

    if (!legacyError.contains('word list failed verification')) {
      _w2Wallet = await _getWalletFromLegacySeed(
        mnemonic: mnemonic,
        restoreHeight: restoreHeight,
        password: walletPassword,
      );
    } else if (polyseedError != 'Failed polyseed decode') {
      _w2Wallet = await _getWalletFromPolyseed(
        mnemonic: mnemonic,
        restoreHeight: restoreHeight,
        password: walletPassword,
      );
    }

    if (_w2Wallet == null) {
      throw Exception("Something went wrong when generating seed");
    }

    await storeWalletPassword(walletPassword);

    _w2TxHistory = _w2Wallet!.history();

    await store();
    notifyListeners();
  }

  Future<void> openExisting() async {
    final path = await getWalletPath();

    final password = await getWalletPassword();

    if (password == null) {
      final errorMsg =
          'Failed to open existing wallet: could not get password.';
      log(LogLevel.error, errorMsg);
      throw Exception(errorMsg);
    }

    _w2Wallet = _w2WalletManager.openWallet(path: path, password: password);
    final errorString = _w2WalletManager.errorString();

    if (errorString != '') {
      final errorMsg = 'Failed to open existing wallet: $errorString';
      log(LogLevel.error, errorMsg);
      throw Exception(errorMsg);
    }

    _w2TxHistory = _w2Wallet!.history();

    notifyListeners();
  }

  Future<bool> store() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    return Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_store(Pointer<Void>.fromAddress(walletFfiAddr)),
    );
  }

  Future delete() async {
    _w2WalletManager.closeWallet(_w2Wallet!, false);
    _w2Wallet = null;
    _hasAttemptedConnection = false;
    _isConnected = false;
    _isSynced = false;
    _syncedHeight = null;
    _unlockedBalance = null;
    _totalBalance = null;
    _txHistory = [];
    final path = await getWalletPath();
    await File(path).delete();

    await SharedPreferencesService.remove(SharedPreferencesKeys.txHistoryCount);
    await SharedPreferencesService.remove(
      SharedPreferencesKeys.walletRestoreHeight,
    );
    await SharedPreferencesService.remove(SharedPreferencesKeys.appLockEnabled);
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
    final w2WalletFfiAddr = _w2Wallet!.ffiAddress();

    final connected = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connected(Pointer<Void>.fromAddress(w2WalletFfiAddr)),
    );

    return connected != 0;
  }

  Future<void> loadIsSynced() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    _isSynced = await Isolate.run(
      () =>
          // ignore: deprecated_member_use
          monero.Wallet_synchronized(Pointer<Void>.fromAddress(walletFfiAddr)),
    );
  }

  Future<void> loadSyncedHeight() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    _syncedHeight = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_blockChainHeight(
        Pointer<Void>.fromAddress(walletFfiAddr),
      ),
    );
  }

  Future<void> loadTotalBalance() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_balance(
        Pointer<Void>.fromAddress(walletFfiAddr),
        accountIndex: 0,
      ),
    );

    _totalBalance = doubleAmountFromInt(amount);
  }

  Future<void> loadUnlockedBalance() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_unlockedBalance(
        Pointer<Void>.fromAddress(walletFfiAddr),
        accountIndex: 0,
      ),
    );

    _unlockedBalance = doubleAmountFromInt(amount);
  }

  String getPrimaryAddress() {
    return _w2Wallet!.address(accountIndex: 0);
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

    return _w2Wallet!.address(accountIndex: 0, addressIndex: nextSubaddrIndex);
  }

  Future<MoneroPendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll,
  ) async {
    final amountInt = _w2Wallet!.amountFromDouble(amount);
    final w2WalletFfiAddr = _w2Wallet!.ffiAddress();

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

    final pendingTx = MoneroPendingTransaction(txPointer);

    if (pendingTx.errorString() != '') {
      throw Exception(pendingTx.errorString());
    }

    return pendingTx;
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
      key: _w2Wallet!.getTxKey(txid: tx.txid('')),
    );

    await addPendingOutgoingTx(txDetails);
    await refresh();
    await loadTxHistory();
  }

  String resolveOpenAlias(String address) {
    return _w2WalletManager.resolveOpenAlias(
      address: address,
      dnssecValid: true,
    );
  }

  Future<void> addPendingOutgoingTx(TxDetails tx) async {
    final pendingOutgoingTxs = await _getPendingOutgoingTxs();
    pendingOutgoingTxs.add(tx);
    await _persistPendingOutgoingTxs(pendingOutgoingTxs);
  }

  Future<void> _removePendingOutgoingTx(String hash) async {
    final pendingOutgoingTxs = await _getPendingOutgoingTxs();
    pendingOutgoingTxs.removeWhere((tx) => tx.hash == hash);
    _persistPendingOutgoingTxs(pendingOutgoingTxs);
  }

  Future<void> _persistPendingOutgoingTxs(List<TxDetails> txs) async {
    final txsJson = txs.map((tx) => json.encode(tx)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      SharedPreferencesKeys.pendingOutgoingTxs,
      txsJson,
    );
  }

  Future<List<TxDetails>> _getPendingOutgoingTxs() async {
    final prefs = await SharedPreferences.getInstance();
    final txsJson =
        prefs.getStringList(SharedPreferencesKeys.pendingOutgoingTxs) ?? [];

    final txs = txsJson
        .map(
          (jsonString) => TxDetails.fromJson(
            json.decode(jsonString) as Map<String, dynamic>,
          ),
        )
        .toList();

    return txs;
  }

  Future<double> getPendingOutgoingTxsAmountSum() async {
    final txs = await _getPendingOutgoingTxs();

    final amountSum = txs
        .map((tx) => tx.amount + tx.fee)
        .reduce((value, el) => value + el);

    return amountSum;
  }

  List<TxDetails> _getConfirmedTxHistory() {
    final txCount = _w2TxHistory!.count();
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
    final pendingOutgoingTxs = await _getPendingOutgoingTxs();
    final confirmedTxHistory = _getConfirmedTxHistory();

    final confirmedTxMap = {for (var tx in confirmedTxHistory) tx.hash: tx};
    final fullTxHistory = <TxDetails>[];

    fullTxHistory.addAll(confirmedTxHistory);

    for (final pendingOutgoingTx in pendingOutgoingTxs) {
      if (confirmedTxMap.containsKey(pendingOutgoingTx.hash)) {
        _removePendingOutgoingTx(pendingOutgoingTx.hash);
      } else {
        fullTxHistory.add(pendingOutgoingTx);
      }
    }

    fullTxHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return fullTxHistory;
  }

  TxDetails getTxDetails(int txIndex) {
    final tx = _w2TxHistory!.transaction(txIndex);
    final direction = tx.direction();
    final hash = tx.hash();
    final amountSent = doubleAmountFromInt(tx.amount());
    final fee = doubleAmountFromInt(tx.fee());
    final timestamp = tx.timestamp();
    final height = tx.blockHeight();
    final confirmations = _w2Wallet!.blockChainHeight() - height + 1;
    final key = _w2Wallet!.getTxKey(txid: hash);

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
