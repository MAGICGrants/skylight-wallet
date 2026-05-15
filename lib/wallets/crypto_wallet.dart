import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/logging.dart';

class TxRecipient {
  final String address;
  final double amount;

  TxRecipient(this.address, this.amount);

  Map<String, dynamic> toJson() => {'address': address, 'amount': amount};

  factory TxRecipient.fromJson(Map<String, dynamic> json) =>
      TxRecipient(json['address'] as String, (json['amount'] as num).toDouble());
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

/// Coin-agnostic handle for a transaction that has been built but not
/// yet broadcast to the network.
abstract class PendingTransaction {
  double get amount;
  double get fee;
}

class WalletConnectionDetails {
  final String address;
  final String proxyPort;
  final bool useTor;
  final bool useSsl;

  WalletConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useTor,
    required this.useSsl,
  });
}

/// Coin-agnostic base for a single-currency wallet.
///
/// Subclasses implement the abstract hooks to talk to a specific chain.
/// Concrete methods on this class own the shared lifecycle, persistence
/// of connection/tx counters, periodic refresh, and change notification.
abstract class CryptoWallet with ChangeNotifier {
  CryptoWallet() {
    _startTimers();
  }

  // ----- Coin metadata (subclass) -----

  String get coinSymbol;
  String get coinName;
  String get iconAsset;
  int get decimals;
  int get smallerDigits;

  /// Human-readable name of the kind of server this coin connects to,
  /// used in connection-setup copy (e.g. "LWS server", "Electrum server").
  String get connectionTypeName;

  /// Example address shown as the placeholder in the connection-setup
  /// form's address field (e.g. `192.168.1.1:18090` for Monero LWS,
  /// `electrum.example.com:50002` for an Electrum server).
  String get connectionAddressExample;

  // ----- Internal state -----

  final int _sessionStartedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  String _connectionAddress = '';
  String _connectionProxyPort = '';
  bool _connectionUseTor = false;
  bool _connectionUseSsl = false;
  bool _hasAttemptedConnection = false;
  bool _isConnected = false;
  bool _isSynced = false;
  int? _syncedHeight;
  double? _unlockedBalance;
  double? _totalBalance;
  List<TxDetails> _txHistory = [];
  bool _isLoaded = false;

  Timer? _connectionTimer;
  Timer? _refreshTimer;

  // ----- Public getters -----

  String get connectionAddress => _connectionAddress;
  String get connectionProxyPort => _connectionProxyPort;
  bool get connectionUseTor => _connectionUseTor;
  bool get connectionUseSsl => _connectionUseSsl;
  bool get usingTor => _connectionUseTor;
  bool get hasAttemptedConnection => _hasAttemptedConnection;
  bool get isConnected => _isConnected;
  bool get isSynced => _isSynced;
  int? get syncedHeight => _syncedHeight;
  double? get unlockedBalance => _unlockedBalance;
  double? get totalBalance => _totalBalance;
  List<TxDetails> get txHistory => _txHistory;
  bool get isLoaded => _isLoaded;

  /// True when the wallet has been opened/restored AND a server connection
  /// is configured. Inactive wallets show only as "Set up" entries in the
  /// home screen.
  bool get isActive => _isLoaded && _connectionAddress.isNotEmpty;

  // ----- Namespaced SharedPreferences -----

  @protected
  String prefKey(String name) => '${coinSymbol.toLowerCase()}_$name';

  // ----- Lifecycle hooks (subclass) -----

  Future<bool> hasExistingWallet();

  Future<void> openExisting({required String password});

  Future<void> restoreFromMasterSeed({
    required String bip39Mnemonic,
    required DateTime restoreDate,
    required String password,
  });

  Future<bool> store();

  /// Removes the on-disk wallet file(s). The base [delete] orchestration
  /// calls this and then clears namespaced prefs.
  Future<void> deleteFiles();

  // ----- Daemon / refresh hooks (subclass) -----

  Future<void> connectToDaemonImpl({
    required String address,
    String? proxyPort,
    required bool useSsl,
  });

  /// Coin-specific connectivity probe for the connection-setup form.
  ///
  /// Performs a single round-trip to the supplied [address] using
  /// whatever protocol this coin's daemon speaks (HTTP POST for Monero
  /// LWS, JSON-RPC over TCP for Electrum, etc). Throws on failure with
  /// a human-readable error.
  ///
  /// Implementations MUST NOT mutate the wallet's live connection state;
  /// the probe should be entirely standalone.
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
  });

  Future<bool> getIsConnected();
  Future<void> refresh();
  Future<void> loadIsSynced();
  Future<void> loadSyncedHeight();
  Future<void> loadUnlockedBalance();
  Future<void> loadTotalBalance();
  Future<int> getCurrentHeight();
  Future<int> getRestoreHeight();
  List<TxDetails> readTxHistory();

  // ----- Send/receive hooks (subclass) -----

  String getPrimaryAddress();

  /// Returns the address to use for a fresh incoming payment. Defaults to
  /// the primary address; coins with HD addresses (e.g. subaddresses)
  /// override.
  String? getReceiveAddress() => getPrimaryAddress();

  bool isAddressValid(String address);

  Future<PendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority = 0,
  });

  Future<void> commitTx(PendingTransaction tx, String destinationAddress);

  /// Hook fired after [loadTxHistory] detects that the tx history grew.
  /// Subclasses may use this to update derived state (e.g. next unused
  /// subaddress for Monero).
  @protected
  Future<void> onTxHistoryGrew() async {}

  // ----- Connection details persistence (concrete) -----

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

  Future<void> persistCurrentConnection() async {
    await SharedPreferencesService.set(prefKey('connectionAddress'), _connectionAddress);
    await SharedPreferencesService.set(prefKey('connectionProxyPort'), _connectionProxyPort);
    await SharedPreferencesService.set(prefKey('connectionUseTor'), _connectionUseTor);
    await SharedPreferencesService.set(prefKey('connectionUseSsl'), _connectionUseSsl);
  }

  Future<WalletConnectionDetails> getPersistedConnection() async {
    return WalletConnectionDetails(
      address: await SharedPreferencesService.get<String>(prefKey('connectionAddress')) ?? '',
      proxyPort: await SharedPreferencesService.get<String>(prefKey('connectionProxyPort')) ?? '',
      useTor: await SharedPreferencesService.get<bool>(prefKey('connectionUseTor')) ?? false,
      useSsl: await SharedPreferencesService.get<bool>(prefKey('connectionUseSsl')) ?? false,
    );
  }

  Future<void> loadPersistedConnection() async {
    final c = await getPersistedConnection();
    setConnection(address: c.address, proxyPort: c.proxyPort, useTor: c.useTor, useSsl: c.useSsl);
  }

  // ----- Tx history persistence (concrete) -----

  Future<void> loadTxHistory({bool persistCount = true}) async {
    final newHistory = readTxHistory();
    var hasPendingTx = false;

    if (_txHistory.isNotEmpty) {
      final lastTx = _txHistory[0];
      if (lastTx.confirmations < 10) hasPendingTx = true;
    }

    final txCountDiff = newHistory.length - _txHistory.length;
    final hadGrowth = txCountDiff > 0;

    if (hadGrowth || hasPendingTx) {
      _txHistory = newHistory;

      if ((Platform.isLinux || Platform.isWindows || Platform.isMacOS) &&
          _isConnected &&
          _isSynced &&
          _syncedHeight is int &&
          _syncedHeight! > 0) {
        for (int i = 0; i < txCountDiff; i++) {
          final tx = _txHistory[i];
          if (tx.direction == consts.txDirectionIncoming && tx.timestamp > _sessionStartedAt) {
            NotificationService().showIncomingTxNotification(tx.amount);
            break;
          }
        }
      }

      if (persistCount) {
        await persistTxHistoryCount();
      }
    }

    if (hadGrowth) {
      await onTxHistoryGrew();
    }
  }

  Future<void> persistTxHistoryCount() async {
    if (_txHistory.isEmpty) return;
    await SharedPreferencesService.set<int>(prefKey('txHistoryCount'), _txHistory.length);
  }

  Future<int> getPersistedTxHistoryCount() async {
    return await SharedPreferencesService.get<int>(prefKey('txHistoryCount')) ?? 0;
  }

  // ----- High-level orchestration -----

  /// Steady-state refresh: pulls latest state from the daemon, loads stats,
  /// and (if a connection is configured) connects to the daemon. Safe to
  /// call when the wallet has not been opened yet.
  Future<void> load() async {
    if (!_isLoaded) return;
    await refresh();
    await loadAllStats();
    if (_connectionAddress.isNotEmpty) {
      await connectToDaemon();
    }
  }

  Future<void> loadAllStats() async {
    if (!_isLoaded) {
      log(LogLevel.warn, '[$coinSymbol] Attempted loadAllStats but wallet is not loaded.');
      return;
    }

    await Future.wait([
      loadIsSynced(),
      loadSyncedHeight(),
      loadUnlockedBalance(),
      loadTotalBalance(),
      loadTxHistory(),
    ]);

    notifyListeners();
  }

  Future<void> connectToDaemon() async {
    if (!_isLoaded) {
      throw Exception('[$coinSymbol] Cannot connect: wallet not loaded.');
    }

    String? torProxyPort;
    if (_connectionUseTor) {
      final proxyInfo = await TorSettingsService.sharedInstance.getProxy();
      if (proxyInfo != null) {
        torProxyPort = proxyInfo.port.toString();
      }
    }
    final proxyPort = torProxyPort ?? _connectionProxyPort;

    await connectToDaemonImpl(
      address: _connectionAddress,
      proxyPort: proxyPort,
      useSsl: _connectionUseSsl,
    );

    _hasAttemptedConnection = true;
    notifyListeners();
  }

  Future<void> delete() async {
    await deleteFiles();
    await clearPersistedState();
    setIsLoaded(false);
  }

  /// Clears all SharedPreferences keys namespaced under this wallet.
  Future<void> clearPersistedState() async {
    const keys = [
      'connectionAddress',
      'connectionProxyPort',
      'connectionUseTor',
      'connectionUseSsl',
      'walletRestoreHeight',
      'txHistoryCount',
    ];
    for (final k in keys) {
      await SharedPreferencesService.remove(prefKey(k));
    }
  }

  // ----- Protected state mutators (used by subclasses) -----

  @protected
  int get sessionStartedAt => _sessionStartedAt;

  @protected
  void setIsLoaded(bool value) {
    _isLoaded = value;
    if (!value) {
      _hasAttemptedConnection = false;
      _isConnected = false;
      _isSynced = false;
      _syncedHeight = null;
      _unlockedBalance = null;
      _totalBalance = null;
      _txHistory = [];
    }
    notifyListeners();
  }

  @protected
  void setIsConnected(bool value) {
    _isConnected = value;
  }

  @protected
  void setIsSynced(bool value) {
    _isSynced = value;
  }

  @protected
  void setSyncedHeight(int? value) {
    _syncedHeight = value;
  }

  @protected
  void setUnlockedBalance(double? value) {
    _unlockedBalance = value;
  }

  @protected
  void setTotalBalance(double? value) {
    _totalBalance = value;
  }

  // ----- Timers -----

  void _startTimers() {
    _connectionTimer = Timer.periodic(Duration(seconds: 1), (_) => _checkConnectionTask());
    _refreshTimer = Timer.periodic(Duration(seconds: 20), (_) => _refreshTask());
  }

  Future<void> _checkConnectionTask() async {
    if (!_isLoaded) return;
    final connected = await getIsConnected();
    if (connected != _isConnected) {
      log(LogLevel.info, '[$coinSymbol] Connection status changed to: $connected');
      _isConnected = connected;
      notifyListeners();
    }
  }

  Future<void> _refreshTask() async {
    if (!_isLoaded) return;
    await refresh();
    try {
      await loadAllStats().timeout(Duration(seconds: 20));
    } catch (e) {
      log(LogLevel.error, '[$coinSymbol] Error loading all stats: $e');
    }
    await store();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
