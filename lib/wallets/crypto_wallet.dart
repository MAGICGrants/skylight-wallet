import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openalias_ffi/openalias_ffi.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/logging.dart';

class TxRecipient {
  final String address;
  final double amount;
  final bool isChange;

  TxRecipient(this.address, this.amount, {this.isChange = false});

  Map<String, dynamic> toJson() => {
    'address': address,
    'amount': amount,
    if (isChange) 'isChange': true,
  };

  factory TxRecipient.fromJson(Map<String, dynamic> json) => TxRecipient(
    json['address'] as String,
    (json['amount'] as num).toDouble(),
    isChange: json['isChange'] as bool? ?? false,
  );
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

  /// Unix seconds when the tx was first seen in the mempool or broadcast by
  /// this wallet. Used for display instead of block time when set.
  final int? broadcastAt;

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
    this.broadcastAt,
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
    if (broadcastAt != null) 'broadcastAt': broadcastAt,
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
    broadcastAt: json['broadcastAt'] as int?,
  );
}

List<TxDetails> parseCachedTxHistory(String txJson) {
  final list = jsonDecode(txJson) as List<dynamic>;
  return list.map((j) => TxDetails.fromJson(j as Map<String, dynamic>)).toList();
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

  /// Coin-specific server kind (e.g. Monero 'lws' vs 'node'). '' = default.
  final String connectionType;

  WalletConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useTor,
    required this.useSsl,
    this.connectionType = '',
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

  /// Symbol/decimals the network fee is denominated in. Defaults to this
  /// coin's own; ERC-20 tokens override to the chain's native coin (ETH),
  /// since gas is paid in ETH, not the token.
  String get feeCoinSymbol => coinSymbol;
  int get feeDecimals => decimals;
  String get feeIconAsset => iconAsset;

  /// True when the network fee is paid in a different currency than the amount
  /// being sent (ERC-20 tokens: amount in token, fee in ETH).
  bool get feeIsForeign => feeCoinSymbol != coinSymbol;

  /// OpenAlias asset tag (the `oa1:<asset>` prefix), e.g. `'btc'`, `'xmr'`.
  /// Empty when the coin has no OpenAlias support. Used by
  /// [resolveOpenAliasAddress] (DNSSEC-validated, over Tor).
  String get openAliasAsset => '';

  /// Resolves an OpenAlias [domain] to an address for this coin with end-to-end
  /// DNSSEC validation, over Tor. Returns the address if valid, else null.
  /// Throws if Tor isn't available or DNSSEC validation fails.
  Future<String?> resolveOpenAliasAddress(String domain) async {
    if (openAliasAsset.isEmpty) return null;
    walletLog(LogLevel.info, 'openalias: resolving "$domain" (asset=$openAliasAsset)');
    final proxy = await TorSettingsService.sharedInstance.getProxy();
    if (proxy == null) {
      walletLog(LogLevel.warn, 'openalias: Tor proxy unavailable');
      throw Exception('Tor is required to resolve OpenAlias.');
    }
    walletLog(LogLevel.info, 'openalias: using Tor SOCKS port ${proxy.port}');
    final address = await OpenAliasFfi.resolve(
      domain: domain,
      asset: openAliasAsset,
      socksPort: proxy.port,
    );
    walletLog(LogLevel.info, 'openalias: resolved address = ${address ?? '<null>'}');
    if (address == null) return null;
    final valid = isAddressValid(address);
    walletLog(LogLevel.info, 'openalias: isAddressValid=$valid');
    return valid ? address : null;
  }

  /// Human-readable name of the kind of server this coin connects to,
  /// used in connection-setup copy (e.g. "LWS server", "Electrum server").
  String get connectionTypeName;

  /// Example address shown as the placeholder in the connection-setup
  /// form's address field (e.g. `192.168.1.1:18090` for Monero LWS,
  /// `electrum.example.com:50002` for an Electrum server).
  String get connectionAddressExample;

  /// Selectable server kinds for this coin (e.g. Monero `['lws','node']`).
  /// Empty ⇒ the connection form shows no type toggle.
  List<String> get connectionTypeOptions => const [];

  /// Example address placeholder for a specific [connectionType]. Defaults to
  /// [connectionAddressExample]; coins with multiple types override this.
  String connectionAddressExampleForType(String connectionType) => connectionAddressExample;

  /// The currently-configured server kind (one of [connectionTypeOptions]).
  String get connectionType => _connectionType;

  /// Confirmations required before a transaction is treated as fully
  /// confirmed in the UI (no pending indicator).
  int get requiredConfirmations;

  /// True for testnet / regtest coins that should not use mainnet fiat
  /// pricing or other mainnet-only behaviour.
  bool get isTestnet => false;

  /// When true, unconfirmed (pending) balance is spendable and the UI should
  /// not show a separate pending amount below the main balance.
  bool get canSpendPendingBalance => false;

  /// True when [tx] has enough confirmations to hide the pending indicator.
  bool isTxConfirmed(TxDetails tx) => tx.height != -1 && tx.confirmations >= requiredConfirmations;

  /// Logs [message] prefixed with [coinSymbol].
  @protected
  void walletLog(LogLevel level, String message, {Map<String, dynamic>? meta}) {
    log(level, message, meta: meta, coin: coinSymbol);
  }

  // ----- Internal state -----

  final int _sessionStartedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  String _connectionAddress = '';
  String _connectionProxyPort = '';
  bool _connectionUseTor = false;
  bool _connectionUseSsl = false;
  String _connectionType = '';

  // Optional explorer connection (its own server, parallel to the node above).
  String _explorerAddress = '';
  String _explorerProxyPort = '';
  bool _explorerUseTor = false;
  bool _explorerUseSsl = false;
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
  bool _disposed = false;
  bool _connectionCheckInFlight = false;
  bool _refreshInFlight = false;

  bool _enabledInApp = true;

  /// When false, the wallet is hidden from the UI and excluded from sync.
  bool get enabledInApp => _enabledInApp;

  void setEnabledInApp(bool value) {
    if (_enabledInApp == value) return;
    _enabledInApp = value;
    notifyListeners();
  }

  // ----- Public getters -----

  String get connectionAddress => _connectionAddress;
  String get connectionProxyPort => _connectionProxyPort;
  bool get connectionUseTor => _connectionUseTor;
  bool get connectionUseSsl => _connectionUseSsl;

  String get explorerAddress => _explorerAddress;
  String get explorerProxyPort => _explorerProxyPort;
  bool get explorerUseTor => _explorerUseTor;
  bool get explorerUseSsl => _explorerUseSsl;

  /// True when this coin supports an optional explorer (its own setup screen).
  /// Default false (BTC/XMR).
  bool get supportsExplorerUrl => false;

  /// Placeholder shown in the explorer address field.
  String get explorerAddressExample => '';
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
  bool get isActive => _enabledInApp && _isLoaded && _connectionAddress.isNotEmpty;

  // ----- Namespaced SharedPreferences -----

  @protected
  String prefKey(String name) => '${coinSymbol.toLowerCase()}_$name';

  /// Coin symbol whose namespace holds the node/explorer connection prefs.
  /// Defaults to this coin; coins that [usesParentConnection] override it to
  /// the parent so they read/write the same connection config.
  @protected
  String get connectionPrefSymbol => coinSymbol;

  String _connPrefKey(String name) => '${connectionPrefSymbol.toLowerCase()}_$name';

  // ----- Lifecycle hooks (subclass) -----

  Future<bool> hasExistingWallet();

  Future<void> openExisting({required String password});

  Future<void> restoreFromMasterSeed({
    required String bip39Mnemonic,
    required DateTime restoreDate,
    required String password,
  });

  Future<bool> store();

  /// True when the open wallet was built for a different connection than the
  /// one now configured, so it must be deleted and re-recovered from the
  /// master seed. Default false; Monero overrides this for LWS↔node switches.
  Future<bool> needsRebuildForCurrentConnection() async => false;

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
    String connectionType = '',
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
    String connectionType = '',
  }) {
    _connectionAddress = address;
    _connectionProxyPort = proxyPort;
    _connectionUseTor = useTor;
    _connectionUseSsl = useSsl;
    _connectionType = connectionType;
    notifyListeners();
  }

  /// The explorer has its own server (parallel to the node), set/persisted
  /// independently via its own setup form.
  void setExplorerConnection({
    required String address,
    required String proxyPort,
    required bool useTor,
    required bool useSsl,
  }) {
    _explorerAddress = address;
    _explorerProxyPort = proxyPort;
    _explorerUseTor = useTor;
    _explorerUseSsl = useSsl;
    notifyListeners();
  }

  /// Probes an explorer endpoint. Coins that support an explorer override this.
  Future<void> testExplorerConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
  }) async {
    throw UnimplementedError('This coin has no explorer.');
  }

  Future<void> persistCurrentConnection() async {
    await SharedPreferencesService.set(_connPrefKey('connectionAddress'), _connectionAddress);
    await SharedPreferencesService.set(_connPrefKey('connectionProxyPort'), _connectionProxyPort);
    await SharedPreferencesService.set(_connPrefKey('connectionUseTor'), _connectionUseTor);
    await SharedPreferencesService.set(_connPrefKey('connectionUseSsl'), _connectionUseSsl);
    await SharedPreferencesService.set(_connPrefKey('connectionType'), _connectionType);
  }

  Future<void> persistExplorerConnection() async {
    await SharedPreferencesService.set(_connPrefKey('explorerAddress'), _explorerAddress);
    await SharedPreferencesService.set(_connPrefKey('explorerProxyPort'), _explorerProxyPort);
    await SharedPreferencesService.set(_connPrefKey('explorerUseTor'), _explorerUseTor);
    await SharedPreferencesService.set(_connPrefKey('explorerUseSsl'), _explorerUseSsl);
  }

  Future<WalletConnectionDetails> getPersistedConnection() async {
    return WalletConnectionDetails(
      address: await SharedPreferencesService.get<String>(_connPrefKey('connectionAddress')) ?? '',
      proxyPort:
          await SharedPreferencesService.get<String>(_connPrefKey('connectionProxyPort')) ?? '',
      useTor: await SharedPreferencesService.get<bool>(_connPrefKey('connectionUseTor')) ?? false,
      useSsl: await SharedPreferencesService.get<bool>(_connPrefKey('connectionUseSsl')) ?? false,
      connectionType:
          await SharedPreferencesService.get<String>(_connPrefKey('connectionType')) ?? '',
    );
  }

  Future<WalletConnectionDetails> getPersistedExplorerConnection() async {
    return WalletConnectionDetails(
      address: await SharedPreferencesService.get<String>(_connPrefKey('explorerAddress')) ?? '',
      proxyPort:
          await SharedPreferencesService.get<String>(_connPrefKey('explorerProxyPort')) ?? '',
      useTor: await SharedPreferencesService.get<bool>(_connPrefKey('explorerUseTor')) ?? false,
      useSsl: await SharedPreferencesService.get<bool>(_connPrefKey('explorerUseSsl')) ?? false,
    );
  }

  Future<void> loadPersistedConnection() async {
    final c = await getPersistedConnection();
    setConnection(
      address: c.address,
      proxyPort: c.proxyPort,
      useTor: c.useTor,
      useSsl: c.useSsl,
      connectionType: c.connectionType,
    );
    final e = await getPersistedExplorerConnection();
    setExplorerConnection(
      address: e.address,
      proxyPort: e.proxyPort,
      useTor: e.useTor,
      useSsl: e.useSsl,
    );
  }

  /// Restores the last known balance and tx list for immediate display on
  /// reopen while a fresh sync runs in the background. Does not require the
  /// wallet file to be opened yet — only a configured connection.
  Future<void> loadPersistedSnapshot() async {
    if (_connectionAddress.isEmpty) return;

    final unlocked = await SharedPreferencesService.get<double>(prefKey('cachedUnlockedBalance'));
    final total = await SharedPreferencesService.get<double>(prefKey('cachedTotalBalance'));
    if (unlocked != null) {
      setUnlockedBalance(unlocked);
      setTotalBalance(total ?? unlocked);
    }

    final txJson = await SharedPreferencesService.get<String>(prefKey('cachedTxHistory'));
    if (txJson != null && txJson.isNotEmpty) {
      try {
        _txHistory = await compute(parseCachedTxHistory, txJson);
      } catch (e) {
        walletLog(LogLevel.warn, 'Failed to load cached tx history: $e');
      }
    }

    notifyListeners();
  }

  /// Persists the current balance and tx list after a successful refresh.
  Future<void> persistWalletSnapshot() async {
    if (!isActive || _unlockedBalance == null) return;

    await SharedPreferencesService.set<double>(prefKey('cachedUnlockedBalance'), _unlockedBalance!);
    await SharedPreferencesService.set<double>(
      prefKey('cachedTotalBalance'),
      _totalBalance ?? _unlockedBalance!,
    );
    await SharedPreferencesService.set<String>(
      prefKey('cachedTxHistory'),
      jsonEncode(_txHistory.map((t) => t.toJson()).toList()),
    );
  }

  // ----- Tx history persistence (concrete) -----

  Future<void> loadTxHistory({bool persistCount = true}) async {
    final previousLength = _txHistory.length;
    final newHistory = readTxHistory();
    var hasPendingTx = false;

    if (newHistory.isNotEmpty && newHistory.first.confirmations < requiredConfirmations) {
      hasPendingTx = true;
    }

    final txCountDiff = newHistory.length - previousLength;
    final hadGrowth = txCountDiff > 0;

    // Keep cached/previous txs when a sync returns nothing (e.g. not connected yet).
    if (newHistory.isNotEmpty || previousLength == 0) {
      _txHistory = newHistory;
    }

    if (hadGrowth || hasPendingTx) {
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

  /// Steady-state refresh: connects to the daemon, pulls latest state,
  /// and loads stats. No-op when the wallet is not loaded or has no server
  /// connection configured.
  Future<void> load() async {
    if (!isActive) return;
    final total = Stopwatch()..start();

    final connectTimer = Stopwatch()..start();
    await connectToDaemon();
    connectTimer.stop();

    final refreshTimer = Stopwatch()..start();
    await refresh();
    refreshTimer.stop();

    final statsTimer = Stopwatch()..start();
    await loadAllStats();
    statsTimer.stop();

    total.stop();
    walletLog(
      LogLevel.info,
      'load in ${total.elapsedMilliseconds}ms '
      '(connect ${connectTimer.elapsedMilliseconds}ms, '
      'refresh ${refreshTimer.elapsedMilliseconds}ms, '
      'loadAllStats ${statsTimer.elapsedMilliseconds}ms)',
    );
  }

  Future<void> loadAllStats() async {
    if (!isActive) return;

    final timer = Stopwatch()..start();

    // Per-task clocks expose which one dominates (usually loadTxHistory).
    final isSyncedTimer = Stopwatch()..start();
    final syncedHeightTimer = Stopwatch()..start();
    final unlockedTimer = Stopwatch()..start();
    final totalBalTimer = Stopwatch()..start();
    final txHistoryTimer = Stopwatch()..start();

    // Render balance + sync state first; don't block it on tx history.
    await Future.wait([
      loadIsSynced().whenComplete(isSyncedTimer.stop),
      loadSyncedHeight().whenComplete(syncedHeightTimer.stop),
      loadUnlockedBalance().whenComplete(unlockedTimer.stop),
      loadTotalBalance().whenComplete(totalBalTimer.stop),
    ]);
    notifyListeners();

    await loadTxHistory().whenComplete(txHistoryTimer.stop);
    notifyListeners();

    final persistTimer = Stopwatch()..start();
    if (await getIsConnected()) {
      await persistWalletSnapshot();
    }
    persistTimer.stop();

    timer.stop();
    walletLog(
      LogLevel.info,
      'loadAllStats in ${timer.elapsedMilliseconds}ms '
      '(isSynced ${isSyncedTimer.elapsedMilliseconds}ms, '
      'syncedHeight ${syncedHeightTimer.elapsedMilliseconds}ms, '
      'unlocked ${unlockedTimer.elapsedMilliseconds}ms, '
      'total ${totalBalTimer.elapsedMilliseconds}ms, '
      'txHistory ${txHistoryTimer.elapsedMilliseconds}ms, '
      'persist ${persistTimer.elapsedMilliseconds}ms)',
    );
  }

  Future<void> connectToDaemon() async {
    if (!isActive) return;
    if (!_isLoaded) {
      throw Exception('[$coinSymbol] Cannot connect: wallet not loaded.');
    }
    await _doConnect();
  }

  /// True when [connectToDaemonImpl] only needs the persisted connection
  /// settings — not the wallet's mnemonic / address state — so the wallet
  /// manager can run it in parallel with [openExisting].
  ///
  /// Default false. Coins whose daemon connect path opens an FFI handle on
  /// the wallet object (e.g. Monero) must leave this false.
  bool get canConnectBeforeOpen => false;

  /// Best-effort connect that runs before [openExisting]. Skips when the
  /// coin doesn't support it or when no connection is configured.
  Future<void> connectBeforeOpen() async {
    if (!canConnectBeforeOpen) return;
    if (!_enabledInApp || _connectionAddress.isEmpty) return;
    await _doConnect();
  }

  /// In-flight connect future, shared between [connectBeforeOpen] and a
  /// later [connectToDaemon]. Prevents the periodic refresh task from
  /// firing a duplicate socket while a pre-open connect is still settling.
  Future<void>? _connectInFlight;

  Future<void> _doConnect() async {
    final existing = _connectInFlight;
    if (existing != null) return existing;
    final future = _connectImpl();
    _connectInFlight = future;
    try {
      await future;
    } finally {
      _connectInFlight = null;
    }
  }

  Future<void> _connectImpl() async {
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
    _isConnected = await getIsConnected();
    notifyListeners();
  }

  Future<void> delete() async {
    await deleteFiles();
    await clearPersistedState();
    setIsLoaded(false);
  }

  Future<void> clearPersistedState() async {
    final keys = [
      'walletRestoreHeight',
      'txHistoryCount',
      'cachedUnlockedBalance',
      'cachedTotalBalance',
      'cachedTxHistory',
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
    _scheduleConnectionCheck();
    _refreshTimer = Timer.periodic(Duration(seconds: 20), (_) => _refreshTask());
  }

  /// Self-rescheduling connection/sync poll. Runs every 1s while the wallet is
  /// still syncing so the UI flips to "synced" within ~1s of catching up, then
  /// backs off to 20s once synced.
  void _scheduleConnectionCheck() {
    if (_disposed) return;
    final interval = _isSynced ? const Duration(seconds: 20) : const Duration(seconds: 1);
    _connectionTimer = Timer(interval, () async {
      await _checkConnectionTask();
      _scheduleConnectionCheck();
    });
  }

  Future<void> _checkConnectionTask() async {
    if (!isActive || _connectionCheckInFlight) return;
    _connectionCheckInFlight = true;
    try {
      final connected = await getIsConnected();
      if (connected != _isConnected) {
        walletLog(LogLevel.info, 'Connection status changed to: $connected');
        _isConnected = connected;
        notifyListeners();
      }
      await pollSyncStatus();
    } finally {
      _connectionCheckInFlight = false;
    }
  }

  /// Runs on the fast (connection-check) cadence. Coins whose sync state can
  /// flip between the slower refresh cycles — e.g. a Monero full node, where a
  /// background thread sets "synchronized" on its own — override this to pick
  /// the change up promptly instead of waiting for the next refresh.
  @protected
  Future<void> pollSyncStatus() async {}

  Future<void> _refreshTask() async {
    if (!isActive || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      try {
        if (!_isConnected) {
          await connectToDaemon();
        }
        await refresh();
      } catch (e) {
        walletLog(LogLevel.warn, 'refresh failed: $e');
      }
      try {
        await loadAllStats().timeout(Duration(seconds: 20));
      } catch (e) {
        walletLog(LogLevel.error, 'Error loading all stats: $e');
      }
      await store();
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
