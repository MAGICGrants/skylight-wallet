// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:dart_date/dart_date.dart';
import 'package:flutter/foundation.dart';
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/monero.dart';
import 'package:monero/src/wallet2.dart';
import 'package:openalias_ffi/openalias_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:polyseed/polyseed.dart';
import 'package:bip39/bip39.dart' as bip39;

import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/amount_units.dart';
import 'package:skylight_wallet/util/bip39.dart';
import 'package:skylight_wallet/util/cacert.dart';
import 'package:skylight_wallet/util/contacts_store.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/util/get_height_by_date.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';
import 'package:skylight_wallet/util/tx_notification_state.dart';
import 'package:skylight_wallet/util/tx_notifications.dart';
import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/util/wallet_password.dart';
import 'package:skylight_wallet/consts.dart' as consts;

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

  factory TxRecipient.fromJson(Map<String, dynamic> json) =>
      TxRecipient(json['address'] as String, (json['amount'] as num).toDouble());
}

class LWSConnectionDetails {
  final String address;
  final String proxyPort;
  final bool useTor;
  final bool useSsl;
  final String connectionType;

  LWSConnectionDetails({
    required this.address,
    required this.proxyPort,
    required this.useTor,
    required this.useSsl,
    this.connectionType = 'lws',
  });
}

class WalletModel with ChangeNotifier {
  // Which factory built the cached manager: 'lws' (LWSF) or 'node' (wallet2).
  Wallet2WalletManager? _w2WalletManager;
  String? _managerType;
  // Mode the currently-open _w2Wallet was loaded for ('lws' | 'node').
  String? _loadedType;
  // True once Wallet_init has run; daemon-dependent FFI calls abort before it.
  bool _daemonInitialized = false;

  Wallet2Wallet? _w2Wallet;
  Wallet2TransactionHistory? _w2TxHistory;

  late String _connectionAddress;
  late String _connectionProxyPort;
  late bool _connectionUseTor;
  late bool _connectionUseSsl;
  String _connectionType = 'lws';
  // False until a connection is in memory (loaded from prefs or set by the
  // settings form). Which wallet file exists/opens depends on it, so anything
  // that resolves a wallet path has to wait for it.
  bool _connectionLoaded = false;

  int? _daemonTargetHeight;
  DateTime? _lastDaemonHeightFetch;

  // Reconnect policy. Seconds to wait before the next attempt, indexed by how
  // many attempts have failed in a row: the first retry is nearly immediate,
  // then it backs off to the refresh cycle's cadence.
  static const _reconnectBackoffSeconds = [1, 2, 5, 10, 20];
  Future<void>? _connectInFlight;
  DateTime? _lastConnectAttempt;
  int _connectFailures = 0;
  // Set when this connection is marked Tor-only but no Tor proxy can be had.
  // Nothing connects while it holds — the alternative is a silent clearnet
  // fallback that leaks the view key and the user's IP to the server.
  bool _torRequirementBroken = false;

  // Serialize periodic tasks + teardown: the raw pointer must not be freed
  // while an isolate read is in flight. Skip-if-busy, not a queue.
  bool _walletBusy = false;
  bool _disposing = false;
  Completer<void>? _walletIdle;

  final _sessionStartedAt = DateTime.now().secondsSinceEpoch;
  var _hasAttemptedConnection = false;
  var _isConnected = false;
  var _isSynced = false;
  int? _syncedHeight;
  double? _unlockedBalance;
  double? _totalBalance;
  List<TxDetails> _txHistory = [];
  bool? _serverSupportsSubaddresses;
  int? _unusedSubaddressIndex;
  bool? _unusedSubaddressIndexIsSupported;
  String? _desktopWalletPassword;

  Wallet2Wallet? get w2Wallet => _w2Wallet;
  String get connectionAddress => _connectionAddress;
  String get connectionProxyPort => _connectionProxyPort;
  bool get connectionUseTor => _connectionUseTor;
  bool get connectionUseSsl => _connectionUseSsl;
  bool get hasAttemptedConnection => _hasAttemptedConnection;
  bool get isConnected => _isConnected;
  bool get isSynced => _isSynced;
  int? get syncedHeight => _syncedHeight;
  double? get unlockedBalance => _unlockedBalance;
  double? get totalBalance => _totalBalance;
  List<TxDetails> get txHistory => _txHistory;
  bool get usingTor => _connectionUseTor;

  /// True when this connection requires Tor but none is available, so the app
  /// is deliberately not connecting at all.
  bool get torRequirementBroken => _torRequirementBroken;
  bool? get serverSupportsSubaddresses => _serverSupportsSubaddresses;
  int? get unusedSubaddressIndex => _unusedSubaddressIndex;
  bool? get unusedSubaddressIndexIsSupported => _unusedSubaddressIndexIsSupported;
  String get connectionType => _connectionType;

  /// True when configured to talk to a full Monero node rather than an LWS.
  bool get isNodeMode => _connectionType == 'node';

  /// Manager factory kind the current connection needs ('lws' | 'node').
  String get _desiredManagerType => isNodeMode ? 'node' : 'lws';

  /// Blocks still to scan in node mode while syncing; null in LWS / when synced.
  int? get syncBlocksRemaining {
    if (!isNodeMode || _isSynced) return null;
    final target = _daemonTargetHeight;
    final have = _syncedHeight;
    if (target == null || have == null || target <= 0) return null;
    final remaining = target - have;
    return remaining > 0 ? remaining : null;
  }

  WalletModel() {
    _startTimers();
  }

  /// Returns the wallet manager built by the factory matching the current
  /// connection type. LWS uses the LWSF manager; a full node uses the standard
  /// wallet2 manager. Switching types rebuilds the manager and tears down any
  /// wallet the previous one opened.
  Future<Wallet2WalletManager> _walletManager() async {
    final type = _desiredManagerType;
    if (_w2WalletManager != null && _managerType == type) return _w2WalletManager!;

    if (_w2WalletManager != null && _w2Wallet != null) {
      // Switching factories frees the old wallet; quiesce the timer tasks first.
      await _closeOpenWallet();
    }

    final managerFactory = Monero().walletManagerFactory();
    _w2WalletManager = type == 'node'
        ? managerFactory.getWalletManager()
        : managerFactory.getLWSFWalletManager();
    _managerType = type;
    return _w2WalletManager!;
  }

  /// Frees the open native wallet safely: blocks new periodic tasks, waits for
  /// any in-flight one (they hold the raw pointer), then closes. Only called
  /// from user flows, never a guarded task, so it can't self-deadlock.
  Future<void> _closeOpenWallet() async {
    _disposing = true;
    try {
      if (_walletBusy) {
        _walletIdle = Completer<void>();
        await _walletIdle!.future;
      }
      if (_w2Wallet != null) {
        _w2Wallet!.pauseRefresh();
        _w2WalletManager?.closeWallet(_w2Wallet!, false);
        _w2Wallet = null;
        _w2TxHistory = null;
        _daemonInitialized = false;
        _loadedType = null;
      }
    } finally {
      _disposing = false;
    }
  }

  /// Path of the wallet file for the current mode. LWS keeps the original
  /// `mywallet` path; the node gets a `_node` suffix so toggling modes doesn't
  /// force a rescan.
  Future<String> resolveWalletPath() async {
    return walletPathForType(_connectionType);
  }

  /// Path of the wallet file a given mode ('lws' | 'node') would use.
  Future<String> walletPathForType(String connectionType) async {
    final basePath = await getWalletPath();
    return connectionType == 'node' ? '${basePath}_node' : basePath;
  }

  /// Runs a periodic task, at most one at a time; teardown waits on the
  /// in-flight one before freeing the wallet.
  Future<void> _runGuarded(Future<void> Function() task) async {
    if (_walletBusy || _disposing || _w2Wallet == null) return;
    _walletBusy = true;
    try {
      await task();
    } catch (e) {
      log(LogLevel.warn, 'Periodic wallet task failed: $e');
    } finally {
      _walletBusy = false;
      _walletIdle?.complete();
      _walletIdle = null;
    }
  }

  void _startTimers() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      _runGuarded(_runCheckConnectionTimerTask);
    });

    Timer.periodic(Duration(seconds: 20), (timer) {
      _runGuarded(_runRefreshTimerTask);
    });
  }

  Future<void> _runCheckConnectionTimerTask() async {
    if (_w2Wallet == null) {
      return;
    }

    final isConnected = await getIsConnected();

    if (isConnected != _isConnected && _w2Wallet != null) {
      log(LogLevel.info, 'Connection status changed to: $isConnected');
      _isConnected = isConnected;
      notifyListeners();
    }

    // Awaited so the connect stays inside the guard, not detached past teardown.
    await _retryConnectIfDue();

    // Node sync state flips off the native background thread; poll it here so
    // "blocks remaining" advances between the slower refresh cycles.
    await pollSyncStatus();
  }

  /// Retries a connection that isn't up, on a short backoff.
  ///
  /// Without this the only reconnect is the 20s refresh cycle, so a connect
  /// that fails on launch — Tor not ready yet, node unreachable for a moment —
  /// leaves the wallet doing nothing for up to 20 seconds behind a sync
  /// spinner. `load()` also abandons its refresh + stats when its connect
  /// throws, so those are picked up here once a retry gets through.
  Future<void> _retryConnectIfDue() async {
    if (_w2Wallet == null || _isConnected || _connectInFlight != null) return;
    // Nothing to connect to yet.
    if (!_connectionLoaded || _connectionAddress.isEmpty) return;

    final lastAttempt = _lastConnectAttempt;

    if (lastAttempt != null) {
      final backoffIndex = min(_connectFailures, _reconnectBackoffSeconds.length - 1);
      final wait = Duration(seconds: _reconnectBackoffSeconds[backoffIndex]);
      if (DateTime.now().difference(lastAttempt) < wait) return;
    }

    try {
      await connectToDaemon();
      if (!_isConnected) return;

      await refresh();
      // Same deferral as the refresh cycle: in node mode the stat reads wait
      // until the background scan has caught up.
      if (isNodeMode && !_isSynced) return;
      await loadAllStats();
    } catch (e) {
      log(LogLevel.warn, 'Reconnect attempt failed: $e');
    }
  }

  /// Node-only: reads sync flag + heights off the background scan thread. When
  /// it just caught up, pulls fresh balances/tx immediately.
  Future<void> pollSyncStatus() async {
    if (!isNodeMode || _w2Wallet == null || !_daemonInitialized) return;

    final wasSynced = _isSynced;
    await loadIsSynced();
    await loadSyncedHeight();
    notifyListeners();

    if (!wasSynced && _isSynced) {
      await loadAllStats();
    }
  }

  Future<void> _runRefreshTimerTask() async {
    if (_w2Wallet == null) {
      return;
    }

    // Reconnect if the connection dropped since the last cycle.
    if (!_isConnected) {
      try {
        await connectToDaemon();
      } catch (e) {
        log(LogLevel.warn, 'Reconnect attempt failed: $e');
      }
    }

    await refresh();

    // In node mode, defer the expensive stat reads until the scan has caught
    // up (avoids contending with the native refresh thread). pollSyncStatus
    // handles progress + the one-time catch-up load.
    if (isNodeMode && !_isSynced) {
      await store();
      return;
    }

    try {
      await loadAllStats().timeout(Duration(seconds: 20));
    } catch (e) {
      log(LogLevel.error, 'Error loading all stats: $e');
    }

    await store();
  }

  Future<void> load() async {
    if (_w2Wallet == null) {
      return;
    }

    await loadPersistedSubaddressSupport();
    await loadPersistedUnusedSubaddressIndex();
    // Connect first so the daemon-dependent calls below have an initialized
    // wallet (refresh/stats early-return until connect sets _daemonInitialized).
    await connectToDaemon();
    await refresh();
    await loadAllStats();
    await loadSubaddressSupport();
    await loadUnusedSubaddressIndex();
  }

  Future<void> loadAllStats() async {
    if (_w2Wallet == null) {
      log(LogLevel.warn, 'Attempted to load all stats but there is no wallet open.');
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

  /// Re-reads the transaction list from the wallet's cache.
  ///
  /// Note what this deliberately does *not* do: touch notification state. Every
  /// isolate (UI, foreground service, background task) refreshes history on its
  /// own timer, so anything recorded here would be consumed by whichever one
  /// refreshed first, whether or not it announced anything. That belongs to
  /// [notifyNewIncomingTxs].
  Future<void> loadTxHistory() async {
    final txCount = _w2TxHistory!.count();
    var hasPendingTx = false;

    if (_txHistory.isNotEmpty) {
      final lastTx = txHistory[0];

      if (lastTx.confirmations < 10) {
        hasPendingTx = true;
      }
    }

    if (txCount > _txHistory.length || hasPendingTx) {
      final txCountDiff = txCount - _txHistory.length;

      _txHistory = _getTxHistory();

      // Notify new transactions on desktop
      if ((Platform.isLinux || Platform.isWindows || Platform.isMacOS) &&
          _isConnected &&
          _isSynced &&
          _syncedHeight is int &&
          _syncedHeight! > 0) {
        for (int i = 0; i < txCountDiff; i++) {
          final tx = _txHistory[i];

          if (tx.direction == consts.txDirectionIncoming && tx.timestamp > _sessionStartedAt) {
            NotificationService().showIncomingTxNotification(tx.amount);
            // Only notify one new transaction
            break;
          }
        }
      }
    }

    if (txCount > _txHistory.length) {
      await loadUnusedSubaddressIndex();
    }
  }

  Future<void> persistCurrentConnection() async {
    await SharedPreferencesService.set(SharedPreferencesKeys.connectionAddress, _connectionAddress);
    await SharedPreferencesService.set(
      SharedPreferencesKeys.connectionProxyPort,
      _connectionProxyPort,
    );
    await SharedPreferencesService.set(SharedPreferencesKeys.connectionUseTor, _connectionUseTor);
    await SharedPreferencesService.set(SharedPreferencesKeys.connectionUseSsl, _connectionUseSsl);
    await SharedPreferencesService.set(SharedPreferencesKeys.connectionType, _connectionType);
  }

  Future<LWSConnectionDetails> getPersistedConnection() async {
    return LWSConnectionDetails(
      address:
          await SharedPreferencesService.get<String>(SharedPreferencesKeys.connectionAddress) ?? '',
      proxyPort:
          await SharedPreferencesService.get<String>(SharedPreferencesKeys.connectionProxyPort) ??
          '',
      useTor:
          await SharedPreferencesService.get<bool>(SharedPreferencesKeys.connectionUseTor) ?? false,
      useSsl:
          await SharedPreferencesService.get<bool>(SharedPreferencesKeys.connectionUseSsl) ?? false,
      connectionType:
          await SharedPreferencesService.get<String>(SharedPreferencesKeys.connectionType) ?? 'lws',
    );
  }

  Future<void> loadPersistedConnection() async {
    final connectionDetails = await getPersistedConnection();
    setConnection(
      address: connectionDetails.address,
      proxyPort: connectionDetails.proxyPort,
      useTor: connectionDetails.useTor,
      useSsl: connectionDetails.useSsl,
      connectionType: connectionDetails.connectionType,
    );
  }

  /// Loads the persisted connection unless one is already in memory.
  Future<void> _ensureConnectionLoaded() async {
    if (_connectionLoaded) return;
    await loadPersistedConnection();
  }

  /// Treats everything currently on chain as already seen. Called when a wallet
  /// is created or restored and when notifications are switched on, so the user
  /// is told about what arrives from here on rather than their whole history.
  Future<void> markExistingTxsAsNotified() async {
    await writeTxNotificationState(
      TxNotificationState(cutoff: DateTime.now().secondsSinceEpoch, announcedHashes: const []),
    );
  }

  /// Announces incoming transactions the user hasn't been told about yet.
  ///
  /// Safe to call from any isolate and as often as you like: what has been
  /// announced is persisted, so the background task, the foreground service and
  /// a future caller can't double-announce or cancel each other out.
  Future<void> notifyNewIncomingTxs() async {
    final state = await readTxNotificationState();

    // Never seeded (fresh install, or an upgrade from the old counter): take
    // the current chain as the starting point instead of announcing a backlog.
    if (state.cutoff == null) {
      await markExistingTxsAsNotified();
      return;
    }

    final decision = decideTxNotifications(
      txHistory: _txHistory,
      cutoff: state.cutoff!,
      announcedHashes: state.announcedHashes,
    );

    final notificationsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ??
        false;

    if (notificationsEnabled) {
      for (final tx in decision.toAnnounce) {
        await NotificationService().showIncomingTxNotification(tx.amount);
      }
    }

    // Recorded either way: with notifications off these are still "seen", so
    // switching the setting on later doesn't replay them.
    await writeTxNotificationState(
      TxNotificationState(cutoff: decision.cutoff, announcedHashes: decision.announcedHashes),
    );
  }

  /// Loads balances + tx history from the just-opened monero_c wallet cache,
  /// offline (no daemon). Lets the last-known state render instantly on reopen
  /// while the sync catches up. `TransactionHistory_refresh` here is local — it
  /// re-reads the wallet's cached transfers, not the network.
  Future<void> loadCachedStats() async {
    if (_w2Wallet == null || _w2TxHistory == null) return;

    final historyFfiAddr = _w2TxHistory!.ffiAddress();
    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.TransactionHistory_refresh(Pointer.fromAddress(historyFfiAddr)),
    );

    await Future.wait([loadUnlockedBalance(), loadTotalBalance(), loadTxHistory()]);

    notifyListeners();
  }

  void setConnection({
    required String address,
    required String proxyPort,
    required bool useTor,
    required bool useSsl,
    String connectionType = 'lws',
  }) {
    _connectionAddress = address;
    _connectionProxyPort = proxyPort;
    _connectionUseTor = useTor;
    _connectionUseSsl = useSsl;
    _connectionType = connectionType;
    _connectionLoaded = true;
    // A reconfigured connection gets a clean slate; the next attempt decides
    // again whether Tor is available for it.
    _torRequirementBroken = false;
    notifyListeners();
  }

  /// Called when Tor is switched off globally. A connection that requires Tor
  /// is marked broken and reported disconnected straight away, rather than
  /// looking healthy until the next refresh cycle notices.
  void onGlobalTorDisabled() {
    if (!_connectionUseTor || _torRequirementBroken) return;

    log(LogLevel.warn, 'Tor disabled globally; a Tor-only connection can no longer be used.');
    _torRequirementBroken = true;
    _isConnected = false;
    notifyListeners();
  }

  void setWalletPassword(String password) {
    _desktopWalletPassword = password;
  }

  /// Connects the open wallet to the configured server. Callers that arrive
  /// while an attempt is in flight join it instead of starting a second one:
  /// two overlapping `Wallet_init` calls race on the same native wallet, and
  /// over Tor they burn a second circuit for nothing.
  Future<void> connectToDaemon() async {
    final inFlight = _connectInFlight;
    if (inFlight != null) return inFlight;

    final attempt = _runConnectAttempt();
    _connectInFlight = attempt;

    try {
      await attempt;
    } finally {
      if (identical(_connectInFlight, attempt)) _connectInFlight = null;
      // A connect can fail without throwing — Wallet_connectToDaemon reports
      // failure by logging — so the backoff counts outcomes, not exceptions.
      _connectFailures = _isConnected ? 0 : _connectFailures + 1;
    }
  }

  Future<void> _runConnectAttempt() async {
    if (_w2Wallet == null) throw Exception("w2wallet is null");

    _lastConnectAttempt = DateTime.now();

    // The open wallet is bound to the factory of the mode it was opened in
    // (LWS vs node). Connecting before a rebuild would call Wallet_init with a
    // mismatched lightWallet flag and abort.
    if (_loadedType != null && _loadedType != _desiredManagerType) {
      log(
        LogLevel.warn,
        'Skipping connect: loaded as "$_loadedType" but connection needs "$_desiredManagerType"; awaiting rebuild',
      );
      return;
    }

    String? torProxyPort;

    if (_connectionUseTor) {
      final proxyInfo = await TorSettingsService.sharedInstance.getProxy();

      if (proxyInfo == null) {
        // Fail closed. Carrying on would leave proxyAddress empty and Wallet_init
        // would reach the server directly — handing it the primary address, the
        // private view key and the real IP, every refresh cycle, on a connection
        // the user marked Tor-only. Never fall back to clearnet.
        log(LogLevel.warn, 'Connection requires Tor but no proxy is available; not connecting.');
        _torRequirementBroken = true;
        _hasAttemptedConnection = true;
        _isConnected = false;
        notifyListeners();
        return;
      }

      torProxyPort = proxyInfo.port.toString();
    }

    _torRequirementBroken = false;

    final proxyPort = torProxyPort ?? _connectionProxyPort;

    if (Platform.isAndroid) {
      // This addresses SSL certificate verification issues on Android
      final cacertFile = await getCacertFile();
      _w2Wallet!.setCaFilePath(cacertFile.path);
    }

    await _connectToDaemon(
      address: _connectionAddress,
      proxyPort: proxyPort,
      useSsl: _connectionUseSsl,
    );

    _hasAttemptedConnection = true;
    // Read the outcome now rather than leaving it to the 1s poll — that's up to
    // a second of sync spinner after a connection is already up.
    _isConnected = await getIsConnected();

    notifyListeners();
  }

  Future<void> _connectToDaemon({
    required String address,
    String? proxyPort,
    bool useSsl = false,
  }) async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final daemonAddress = '${useSsl ? 'https://' : 'http://'}$address';
    final proxyAddress = proxyPort != '' ? '127.0.0.1:$proxyPort' : '';
    // A full node scans locally (lightWallet=false); LWS scans server-side.
    final lightWallet = !isNodeMode;
    final isNode = isNodeMode;

    log(LogLevel.info, 'Calling Wallet_init with parameters:');
    log(LogLevel.info, '  daemonAddress: $daemonAddress');
    log(LogLevel.info, '  proxyAddress: $proxyAddress');
    log(LogLevel.info, '  useSsl: $useSsl');
    log(LogLevel.info, '  lightWallet: $lightWallet');

    // Run init + connect (+ node refresh-thread kick) in a single isolate hop
    // and time each step so a slow daemon handshake is attributable.
    final r = await Isolate.run(() {
      final ptr = Pointer<Void>.fromAddress(walletFfiAddr);
      final sw = Stopwatch()..start();
      // ignore: deprecated_member_use
      final initResult = monero.Wallet_init(
        ptr,
        daemonAddress: daemonAddress,
        proxyAddress: proxyAddress,
        useSsl: useSsl,
        lightWallet: lightWallet,
      );
      final initMs = sw.elapsedMilliseconds;
      sw.reset();
      // ignore: deprecated_member_use
      final connectResult = monero.Wallet_connectToDaemon(ptr);
      final connectMs = sw.elapsedMilliseconds;
      sw.reset();
      var refreshMs = 0;
      if (isNode) {
        // ignore: deprecated_member_use
        monero.Wallet_setAutoRefreshInterval(ptr, millis: 10000);
        // ignore: deprecated_member_use
        monero.Wallet_startRefresh(ptr);
        refreshMs = sw.elapsedMilliseconds;
      }
      return (
        initResult: initResult,
        connectResult: connectResult,
        initMs: initMs,
        connectMs: connectMs,
        refreshMs: refreshMs,
      );
    });

    log(
      LogLevel.info,
      'Wallet connect timings: init ${r.initMs}ms (result ${r.initResult}), '
      'connectToDaemon ${r.connectMs}ms (result ${r.connectResult}), '
      'startRefresh ${r.refreshMs}ms',
    );

    _daemonInitialized = true;

    final connectError = _w2Wallet!.errorString();

    if (connectError != '') {
      log(LogLevel.warn, 'Wallet_connectToDaemon error: $connectError');
    }
  }

  /// Probes a connection without opening the wallet. Throws on failure.
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
    String connectionType = '',
  }) async {
    if (connectionType == 'node') {
      await _testNodeConnection(
        address: address,
        proxyPort: proxyPort,
        useSsl: useSsl,
        useTor: useTor,
      );
      return;
    }

    final url = '${useSsl ? 'https' : 'http'}://$address/get_address_info';
    log(LogLevel.info, 'Probing LWS server: $url (tor=$useTor, proxyPort=$proxyPort)');

    late int statusCode;
    if (useTor) {
      final torSettings = TorSettingsService.sharedInstance;
      if (torSettings.torMode == TorMode.disabled) {
        throw Exception('Tor is disabled. Please go back and enable it.');
      }
      final proxyInfo = await torSettings.getProxy();
      if (proxyInfo == null) {
        throw Exception('Could not resolve a Tor proxy.');
      }
      final response = await makeSocksHttpRequest(
        'POST',
        url,
        proxyInfo,
      ).timeout(Duration(seconds: 20));
      statusCode = response.statusCode;
    } else {
      var httpClient = HttpClient();
      if (proxyPort != null && proxyPort.isNotEmpty) {
        httpClient.findProxy = (_) => 'SOCKS localhost:$proxyPort';
      }
      try {
        final request = await httpClient.postUrl(Uri.parse(url));
        final response = await request.close().timeout(Duration(seconds: 10));
        statusCode = response.statusCode;
      } finally {
        httpClient.close(force: true);
      }
    }

    // LWS responds with 500 to an unauthenticated POST to /get_address_info.
    // Anything else means we're not talking to a real LWS endpoint.
    if (statusCode != HttpStatus.internalServerError) {
      throw Exception('Unexpected status $statusCode from $url');
    }
  }

  /// Probes a full Monero node via `GET /get_height`. A real monerod replies
  /// 200 with a JSON body carrying a `height` (and `status`).
  Future<void> _testNodeConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
  }) async {
    final url = '${useSsl ? 'https' : 'http'}://$address/get_height';
    log(LogLevel.info, 'Probing Monero node: $url (tor=$useTor, proxyPort=$proxyPort)');

    late int statusCode;
    dynamic jsonBody;
    if (useTor) {
      final torSettings = TorSettingsService.sharedInstance;
      if (torSettings.torMode == TorMode.disabled) {
        throw Exception('Tor is disabled. Please go back and enable it.');
      }
      final proxyInfo = await torSettings.getProxy();
      if (proxyInfo == null) {
        throw Exception('Could not resolve a Tor proxy.');
      }
      final response = await makeSocksHttpRequest(
        'GET',
        url,
        proxyInfo,
      ).timeout(Duration(seconds: 20));
      statusCode = response.statusCode;
      jsonBody = response.jsonBody;
    } else {
      final httpClient = HttpClient();
      if (proxyPort != null && proxyPort.isNotEmpty) {
        httpClient.findProxy = (_) => 'SOCKS localhost:$proxyPort';
      }
      try {
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close().timeout(Duration(seconds: 10));
        statusCode = response.statusCode;
        final body = await response.transform(utf8.decoder).join();
        try {
          jsonBody = json.decode(body);
        } catch (_) {
          jsonBody = null;
        }
      } finally {
        httpClient.close(force: true);
      }
    }

    if (statusCode != HttpStatus.ok || jsonBody is! Map || jsonBody['height'] == null) {
      throw Exception('Unexpected response ($statusCode) from $url');
    }
  }

  Future<void> loadPersistedSubaddressSupport() async {
    _serverSupportsSubaddresses = await SharedPreferencesService.get<bool>(
      SharedPreferencesKeys.serverSupportsSubaddresses,
    );
  }

  Future<void> loadSubaddressSupport() async {
    // A full node supports subaddresses natively; skip the LWS HTTP probe.
    if (isNodeMode) {
      _serverSupportsSubaddresses = true;
      await SharedPreferencesService.set<bool>(
        SharedPreferencesKeys.serverSupportsSubaddresses,
        true,
      );
      return;
    }

    try {
      final isSupported = await isSubaddressSupported(1);
      _serverSupportsSubaddresses = isSupported;

      await SharedPreferencesService.set<bool>(
        SharedPreferencesKeys.serverSupportsSubaddresses,
        _serverSupportsSubaddresses!,
      );
    } catch (e) {
      //
    }
  }

  Future<void> loadUnusedSubaddressIndex() async {
    final txHistory = _getTxHistory();

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

    if (_unusedSubaddressIndex != nextSubaddrIndex) {
      // Node supports subaddresses natively; skip the LWS HTTP probe.
      if (isNodeMode) {
        _unusedSubaddressIndex = nextSubaddrIndex;
        _unusedSubaddressIndexIsSupported = true;
        await SharedPreferencesService.set<int>(
          SharedPreferencesKeys.unusedSubaddressIndex,
          _unusedSubaddressIndex!,
        );
        await SharedPreferencesService.set<bool>(
          SharedPreferencesKeys.unusedSubaddressIndexIsSupported,
          true,
        );
        notifyListeners();
        return;
      }

      try {
        final isSupported = await isSubaddressSupported(nextSubaddrIndex);
        _unusedSubaddressIndex = nextSubaddrIndex;
        _unusedSubaddressIndexIsSupported = isSupported;

        await SharedPreferencesService.set<int>(
          SharedPreferencesKeys.unusedSubaddressIndex,
          _unusedSubaddressIndex!,
        );
        await SharedPreferencesService.set<bool>(
          SharedPreferencesKeys.unusedSubaddressIndexIsSupported,
          _unusedSubaddressIndexIsSupported!,
        );

        notifyListeners();
      } catch (e) {
        //
      }
    }
  }

  Future<void> loadPersistedUnusedSubaddressIndex() async {
    _unusedSubaddressIndex = await SharedPreferencesService.get<int>(
      SharedPreferencesKeys.unusedSubaddressIndex,
    );
    _unusedSubaddressIndexIsSupported = await SharedPreferencesService.get<bool>(
      SharedPreferencesKeys.unusedSubaddressIndexIsSupported,
    );
  }

  Future<bool> isSubaddressSupported(int subaddrIndex) async {
    final proto = _connectionUseSsl ? 'https' : 'http';
    final url = Uri.parse('$proto://$_connectionAddress/upsert_subaddrs');
    final primaryAddress = getPrimaryAddress();
    final viewKey = _w2Wallet!.secretViewKey();
    final subaddrs = [
      {
        "key": 0,
        "value": [
          [0, subaddrIndex],
        ],
      },
    ];
    final getAll = false;

    final body = json.encode({
      'address': primaryAddress,
      'view_key': viewKey,
      'subaddrs': subaddrs,
      'get_all': getAll,
    });

    log(LogLevel.info, 'Checking subaddress support:');
    log(LogLevel.info, '  url: $url');
    log(LogLevel.info, '  primaryAddress: $primaryAddress');
    log(LogLevel.info, '  viewKey: <hidden>');
    log(LogLevel.info, '  subaddrs: $subaddrs');
    log(LogLevel.info, '  getAll: $getAll');

    var httpStatus = 0;

    for (int i = 0; i < 3; i++) {
      try {
        if (_connectionUseTor) {
          // This POSTs the view key. Without Tor it does not go out at all.
          if (!await TorService.sharedInstance.waitUntilConnected()) {
            throw Exception('Tor is required for this connection but is unavailable.');
          }

          final proxyInfo = TorService.sharedInstance.getProxyInfo();
          final response = await makeSocksHttpRequest(
            'POST',
            url.toString(),
            proxyInfo,
            body: body,
          ).timeout(Duration(seconds: 20));

          httpStatus = response.statusCode;
        } else {
          final response = await http
              .post(url, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(Duration(seconds: 5));

          httpStatus = response.statusCode;
        }

        break;
      } catch (e) {
        if (i == 2) {
          log(LogLevel.warn, 'Failed to check subaddress support after ${i + 1} attempts.');
          log(LogLevel.warn, 'Error: $e');

          rethrow;
        }
      }
    }

    final result = httpStatus == 200;

    log(
      LogLevel.info,
      'Subaddress support check result for subaddress $subaddrIndex: $result (status: $httpStatus)',
    );

    return result;
  }

  Future<void> refresh() async {
    if (_w2Wallet == null || _w2TxHistory == null || !_daemonInitialized) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final historyFfiAddr = _w2TxHistory!.ffiAddress();

    if (isNodeMode) {
      // The background refresh thread does the block scanning; just keep it
      // running and pull the latest tx-history view from the wallet's cache.
      log(LogLevel.info, 'Ensuring full-node refresh thread + history refresh');
      await Isolate.run(
        // ignore: deprecated_member_use
        () => monero.Wallet_startRefresh(Pointer.fromAddress(walletFfiAddr)),
      );
      await Isolate.run(
        // ignore: deprecated_member_use
        () => monero.TransactionHistory_refresh(Pointer.fromAddress(historyFfiAddr)),
      );
      return;
    }

    log(LogLevel.info, 'Calling Wallet_refresh and TransactionHistory_refresh');

    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_refresh(Pointer.fromAddress(walletFfiAddr)),
    );

    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.TransactionHistory_refresh(Pointer.fromAddress(historyFfiAddr)),
    );

    log(LogLevel.info, 'Wallet refresh methods completed successfully');
  }

  Future<(String, int)> create() async {
    // ignore: deprecated_member_use
    final polyseed = await Isolate.run(() => monero.Wallet_createPolyseed());
    log(LogLevel.info, 'Wallet_createPolyseed completed');
    final restoreHeight = getHeightByDate(date: DateTime.now());
    log(LogLevel.info, 'Using blockchain height: $restoreHeight');

    await restoreFromMnemonic(polyseed, restoreHeight, isNewWallet: true);
    await SharedPreferencesService.set<int>(
      SharedPreferencesKeys.walletRestoreHeight,
      restoreHeight,
    );
    refresh().then((_) => connectToDaemon().then((_) => store()));

    return (polyseed, restoreHeight);
  }

  Future<int> getRestoreHeight() async {
    log(LogLevel.info, 'Calling Wallet_getRefreshFromBlockHeight');

    var w2RestoreHeight = _w2Wallet!.getRefreshFromBlockHeight();

    log(LogLevel.info, 'Wallet_getRefreshFromBlockHeight result: $w2RestoreHeight');

    if (w2RestoreHeight > 0) {
      return w2RestoreHeight;
    }

    return await SharedPreferencesService.get<int>(SharedPreferencesKeys.walletRestoreHeight) ?? 0;
  }

  Future<int> getCurrentHeight() async {
    final wmFfiAddr = (await _walletManager()).ffiAddress();

    log(LogLevel.info, 'Calling WalletManager_blockchainHeight');

    final height = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_blockchainHeight(Pointer.fromAddress(wmFfiAddr));
    });

    log(LogLevel.info, 'WalletManager_blockchainHeight result: $height');
    return height;
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

    final wmFfiAddr = (await _walletManager()).ffiAddress();
    final walletPath = await resolveWalletPath();

    log(LogLevel.info, 'Calling WalletManager_recoveryWallet with parameters:');
    log(LogLevel.info, '  mnemonic: <hidden>');
    log(LogLevel.info, '  restoreHeight: $restoreHeight');
    log(LogLevel.info, '  password: <hidden>');
    log(LogLevel.info, '  path: $walletPath');
    log(LogLevel.info, '  isDummy: $isDummy');

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

    log(LogLevel.info, 'WalletManager_recoveryWallet completed');

    return MoneroWallet(Pointer<Void>.fromAddress(walletFfiAddr));
  }

  Future<MoneroWallet> _getWalletFromPolyseed({
    required String mnemonic,
    required int restoreHeight,
    required String password,
    bool isDummy = false,
    bool newWallet = true,
  }) async {
    if (!isDummy && password == '') {
      throw Exception('Password should not be empty.');
    }

    final wmFfiAddr = (await _walletManager()).ffiAddress();
    final walletPath = await resolveWalletPath();

    // `newWallet` is what tells the backend this seed has history to scan. With
    // it set, both backends ignore the restore height: wallet2 starts the scan
    // at the current chain tip and LWSF never asks the server to rescan, so a
    // restored wallet comes up empty.
    final walletFfiAddr = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_createWalletFromPolyseed(
        Pointer.fromAddress(wmFfiAddr),
        mnemonic: mnemonic,
        seedOffset: '',
        restoreHeight: restoreHeight,
        path: isDummy ? '' : walletPath,
        password: password,
        newWallet: newWallet,
        kdfRounds: 1,
      ).address;
    });

    log(LogLevel.info, 'WalletManager_createWalletFromPolyseed completed');

    return MoneroWallet(Pointer<Void>.fromAddress(walletFfiAddr));
  }

  /// Removes the wallet files for the current mode (cache + `.keys` +
  /// `.address.txt`). The other mode's files are left alone.
  Future<void> _deleteWalletFilesForCurrentMode() async {
    final path = await resolveWalletPath();

    for (final p in [path, '$path.keys', '$path.address.txt']) {
      final file = File(p);
      if (await file.exists()) {
        log(LogLevel.warn, 'Removing existing wallet file before restore: $p');
        await file.delete();
      }
    }
  }

  /// Builds the wallet for [mnemonic] with the factory its seed format needs.
  /// A BIP39 mnemonic is converted to the equivalent legacy word list first.
  Future<MoneroWallet> _buildWalletFromMnemonic({
    required String mnemonic,
    required int restoreHeight,
    required String password,
    required bool isPolyseed,
    required bool isNewWallet,
  }) async {
    if (isPolyseed) {
      return _getWalletFromPolyseed(
        mnemonic: mnemonic,
        restoreHeight: restoreHeight,
        password: password,
        newWallet: isNewWallet,
      );
    }

    return _getWalletFromLegacySeed(
      mnemonic: bip39.validateMnemonic(mnemonic) ? getLegacySeedFromBip39(mnemonic) : mnemonic,
      restoreHeight: restoreHeight,
      password: password,
    );
  }

  /// Restores (or, with [isNewWallet], creates) a wallet from [mnemonic].
  /// [isNewWallet] must only be set for a seed generated right now: it tells
  /// the backend there is no history behind the seed, which skips the rescan
  /// from [restoreHeight].
  Future<void> restoreFromMnemonic(
    String mnemonic,
    int restoreHeight, {
    String passphrase = '',
    bool isNewWallet = false,
  }) async {
    final walletPassword = _desktopWalletPassword ?? genWalletPassword();
    final isPolyseed = Polyseed.isValidSeed(mnemonic);

    var wallet = await _buildWalletFromMnemonic(
      mnemonic: mnemonic,
      restoreHeight: restoreHeight,
      password: walletPassword,
      isPolyseed: isPolyseed,
      isNewWallet: isNewWallet,
    );

    // wallet2 refuses to recover onto an existing wallet file, which surfaces
    // as an unexplained restore failure the user can't get out of. Reaching
    // this means the seed itself was accepted (it's decoded before the file is
    // touched), so the mode's derived files can be cleared and the restore
    // retried. Not done when creating a wallet: there'd be no seed in hand to
    // recover a clobbered file from.
    if (!isNewWallet && wallet.errorString().contains('file already exists')) {
      log(LogLevel.warn, 'Restore hit an existing wallet file: ${wallet.errorString()}');
      await _deleteWalletFilesForCurrentMode();

      wallet = await _buildWalletFromMnemonic(
        mnemonic: mnemonic,
        restoreHeight: restoreHeight,
        password: walletPassword,
        isPolyseed: isPolyseed,
        isNewWallet: isNewWallet,
      );
    }

    if ((wallet.errorString() != '' || wallet.status() != 0) &&
        !wallet.errorString().contains('No response from HTTP server')) {
      if (wallet.errorString().contains('word list failed verification') ||
          wallet.errorString().contains('Failed polyseed decode')) {
        throw Exception('Invalid mnemonic.');
      }

      log(LogLevel.error, 'Error restoring from mnemonic: ${wallet.errorString()}');
      throw Exception('Error restoring from mnemonic: ${wallet.errorString()}');
    }

    _w2Wallet = wallet;
    _w2TxHistory = _w2Wallet!.history();
    _loadedType = _desiredManagerType;

    if (!isNewWallet && restoreHeight > 0) {
      // wallet2's polyseed factory derives the scan start from the seed's
      // birthday and drops the height handed to it, so apply it here. The other
      // factories already took it: LWSF's polyseed path honours it once
      // newWallet is false, and both recoveryWallet implementations set it.
      if (isPolyseed && isNodeMode) {
        log(LogLevel.info, 'Setting refresh from block height: $restoreHeight');
        wallet.setRefreshFromBlockHeight(refresh_from_block_height: restoreHeight);
      }

      // Fallback for getRestoreHeight(), which needs a height to rebuild the
      // other mode's wallet file from the seed on an LWS↔node switch.
      await SharedPreferencesService.set<int>(
        SharedPreferencesKeys.walletRestoreHeight,
        restoreHeight,
      );
    }

    // Whatever this seed already has on chain is history, not news — a restore
    // would otherwise announce every incoming transaction it scans.
    await markExistingTxsAsNotified();

    if (Platform.isAndroid || Platform.isIOS) {
      await storeMobileWalletPassword(walletPassword);
    }

    await store();
    notifyListeners();
  }

  Future<void> openExisting({String? desktopWalletPassword}) async {
    // Opening the same file twice leaves two wallets (and two sync loops)
    // running against it; the first is never closed and both write the cache.
    if (_w2Wallet != null && _loadedType == _desiredManagerType) {
      log(LogLevel.warn, 'Wallet is already open for "$_loadedType"; skipping re-open.');
      return;
    }

    final wm = await _walletManager();
    final path = await resolveWalletPath();

    if (desktopWalletPassword != null) {
      _desktopWalletPassword = desktopWalletPassword;
    }

    final password = desktopWalletPassword ?? await getMobileWalletPassword();

    if (password == null) {
      final errorMsg = 'Failed to open existing wallet: could not get password.';
      log(LogLevel.error, errorMsg);
      throw Exception(errorMsg);
    }

    log(LogLevel.info, 'Calling WalletManager_openWallet with parameters:');
    log(LogLevel.info, '  path: $path');
    log(LogLevel.info, '  password: <hidden>');

    final w2Wallet = wm.openWallet(path: path, password: password);

    if (w2Wallet.errorString() != '') {
      final errorMsg = 'WalletManager_openWallet error: ${w2Wallet.errorString()}';
      log(LogLevel.error, errorMsg);
      throw Exception(errorMsg);
    }

    log(LogLevel.info, 'WalletManager_openWallet completed');

    _w2Wallet = w2Wallet;
    _w2TxHistory = _w2Wallet!.history();
    _loadedType = _desiredManagerType;

    notifyListeners();

    // Show last known balances + tx list (from the wallet cache) immediately
    // while the sync catches up.
    await loadCachedStats();
  }

  /// True when the open wallet was loaded for a different mode than the current
  /// connection needs (e.g. user switched LWS↔node) and must be re-opened.
  bool needsRebuildForCurrentConnection() =>
      _w2Wallet != null && _loadedType != null && _loadedType != _desiredManagerType;

  /// Applies a connection change made via the settings form: rebuilds the open
  /// wallet for the new mode if the server kind changed, then (re)syncs.
  Future<void> applyConnectionChange() async {
    if (needsRebuildForCurrentConnection()) {
      await _rebuildForConnectionType();
    }
    await load();
  }

  /// Re-opens the wallet for the current (newly-selected) mode. LWS and node
  /// keep separate cache files sharing the same keys/seed; if the target file
  /// doesn't exist yet it's recovered from the open wallet's seed.
  Future<void> _rebuildForConnectionType() async {
    // Both mode files share the same password; reuse the existing one so a
    // later switch back can still decrypt the other file.
    final password = _desktopWalletPassword ?? await getMobileWalletPassword();
    if (password == null) {
      throw Exception('Cannot rebuild wallet for new connection: no password.');
    }

    // Extract the seed + restore height while the old-mode wallet is still open.
    final polyseed = _w2Wallet!.getPolyseed(passphrase: '');
    final legacySeed = _w2Wallet!.seed(seedOffset: '');
    final mnemonic = polyseed.isNotEmpty ? polyseed : legacySeed;
    final restoreHeight = await getRestoreHeight();

    _daemonTargetHeight = null;
    _lastDaemonHeightFetch = null;

    final targetPath = await resolveWalletPath();
    final targetExists = await File(targetPath).exists();

    if (targetExists) {
      // _walletManager() (via openExisting) closes the old wallet + swaps factory.
      await openExisting(desktopWalletPassword: password);
    } else {
      // Recover the target-mode file from the shared seed. Force the existing
      // password so restoreFromMnemonic doesn't mint a new random one (which
      // would desync the two mode files). restoreFromMnemonic resolves the
      // target path and rebuilds the manager for the new mode.
      _desktopWalletPassword = password;
      await restoreFromMnemonic(mnemonic, restoreHeight);
    }
  }

  /// Stops the native scan thread and checkpoints what it managed to scan.
  ///
  /// Background isolates call this before they finish. Nothing closes the
  /// wallet when a background task returns, so a refresh left running keeps
  /// pulling blocks past the end of the task, and everything scanned since the
  /// last periodic checkpoint would go with the isolate.
  Future<void> pauseSyncAndStore() async {
    if (_w2Wallet == null || !_daemonInitialized) return;

    log(LogLevel.info, 'Pausing refresh and storing the wallet');

    // Sets the refresh-enabled flag; the scan thread stops at its next check.
    _w2Wallet!.pauseRefresh();

    await store();
  }

  Future<bool> store() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    log(LogLevel.info, 'Calling Wallet_store');

    final result = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_store(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_store result: $result');
    return result;
  }

  Future delete() async {
    await _closeOpenWallet();

    _hasAttemptedConnection = false;
    _isConnected = false;
    _isSynced = false;
    _syncedHeight = null;
    _unlockedBalance = null;
    _totalBalance = null;
    _txHistory = [];

    // Remove both mode files (LWS `mywallet*` and node `mywallet_node*`) plus
    // the companion `.keys` / `.address.txt` Monero writes alongside each.
    final base = await getWalletPath();
    for (final b in {base, '${base}_node'}) {
      for (final p in [b, '$b.keys', '$b.address.txt']) {
        final file = File(p);
        if (await file.exists()) await file.delete();
      }
    }

    await SharedPreferencesService.remove(SharedPreferencesKeys.connectionType);
    await clearTxNotificationState();
    await SharedPreferencesService.remove(SharedPreferencesKeys.walletRestoreHeight);
    await SharedPreferencesService.remove(SharedPreferencesKeys.appLockEnabled);
    await SharedPreferencesService.remove(SharedPreferencesKeys.serverSupportsSubaddresses);
    await clearContacts();
    await SharedPreferencesService.remove(SharedPreferencesKeys.unusedSubaddressIndex);
    await SharedPreferencesService.remove(SharedPreferencesKeys.unusedSubaddressIndexIsSupported);
  }

  Future<bool> hasExistingWallet() async {
    // Each mode keeps its own file in a format only its own manager recognizes
    // (LWSF's `mywallet` vs wallet2's `mywallet_node`), so the persisted
    // connection has to be known before looking one up — checking the default
    // LWS path makes a node wallet look like a fresh install and drops the user
    // back into onboarding.
    await _ensureConnectionLoaded();

    final path = await resolveWalletPath();

    log(LogLevel.info, 'Calling WalletManager_walletExists with parameters:');
    log(LogLevel.info, '  path: $path');

    final wm = await _walletManager();
    final exists = wm.walletExists(path);

    log(LogLevel.info, 'WalletManager_walletExists result: $exists');

    final errorString = wm.errorString();

    if (errorString != '') {
      log(LogLevel.error, 'WalletManager_walletExists error: $errorString');
    }

    if (exists) {
      return true;
    }

    return _adoptModeWithExistingWallet();
  }

  /// Recovers from a connection/wallet-file mismatch: when the persisted mode
  /// has no wallet file but the other mode does (e.g. an LWS↔node switch that
  /// was interrupted before the new file was written), switch to the mode we
  /// actually have a wallet for instead of reporting "no wallet" and sending
  /// the user through onboarding on top of an existing wallet.
  Future<bool> _adoptModeWithExistingWallet() async {
    final otherType = isNodeMode ? 'lws' : 'node';
    final otherPath = await walletPathForType(otherType);

    // wallet2 (node) writes `<path>` plus `<path>.keys`; LWSF writes a single
    // `<path>` file.
    final otherExists = await File(otherPath).exists() || await File('$otherPath.keys').exists();

    if (!otherExists) {
      return false;
    }

    log(
      LogLevel.warn,
      'No "$_connectionType" wallet file found but a "$otherType" one exists; '
      'switching the connection type to match.',
    );

    _connectionType = otherType;
    // Persisted, not just in-memory: callers reload the connection from prefs
    // right after this check.
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.connectionType, otherType);
    notifyListeners();

    return true;
  }

  Future<bool> getIsConnected() async {
    if (_w2Wallet == null || !_daemonInitialized) return false;
    final w2WalletFfiAddr = _w2Wallet!.ffiAddress();

    final connected = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connected(Pointer<Void>.fromAddress(w2WalletFfiAddr)),
    );

    return connected != 0;
  }

  Future<void> loadIsSynced() async {
    if (_w2Wallet == null || !_daemonInitialized) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    log(LogLevel.info, 'Calling Wallet_synchronized:');

    final synced = await Isolate.run(
      () =>
          // ignore: deprecated_member_use
          monero.Wallet_synchronized(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_synchronized result: $synced');

    if (isNodeMode && !synced) {
      // Wallet height is local/cheap — read every poll. The daemon tip is a
      // network RPC, so only refresh it every 30s to avoid stealing the
      // circuit/lock from the scan.
      final now = DateTime.now();
      if (_lastDaemonHeightFetch == null ||
          now.difference(_lastDaemonHeightFetch!) >= const Duration(seconds: 30)) {
        _lastDaemonHeightFetch = now;
        _daemonTargetHeight = await Isolate.run(
          // ignore: deprecated_member_use
          () => monero.Wallet_daemonBlockChainHeight(Pointer<Void>.fromAddress(walletFfiAddr)),
        );
        log(LogLevel.info, 'Daemon target height: $_daemonTargetHeight');
      }
    }

    _isSynced = synced;
  }

  Future<void> loadSyncedHeight() async {
    if (_w2Wallet == null || !_daemonInitialized) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    log(LogLevel.info, 'Calling Wallet_blockChainHeight:');

    _syncedHeight = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_blockChainHeight(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_blockChainHeight result: $_syncedHeight');
  }

  Future<void> loadTotalBalance() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    final accountIndex = 0;

    log(LogLevel.info, 'Calling Wallet_balance with parameters:');
    log(LogLevel.info, '  accountIndex: $accountIndex');

    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_balance(
        Pointer<Void>.fromAddress(walletFfiAddr),
        accountIndex: accountIndex,
      ),
    );

    log(LogLevel.info, 'Wallet_balance result: $amount');

    _totalBalance = doubleAmountFromInt(amount);
  }

  Future<void> loadUnlockedBalance() async {
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    final accountIndex = 0;

    log(LogLevel.info, 'Calling Wallet_unlockedBalance with parameters:');
    log(LogLevel.info, '  accountIndex: $accountIndex');

    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_unlockedBalance(
        Pointer<Void>.fromAddress(walletFfiAddr),
        accountIndex: accountIndex,
      ),
    );

    log(LogLevel.info, 'Wallet_unlockedBalance result: $amount');

    _unlockedBalance = doubleAmountFromInt(amount);
  }

  String getPrimaryAddress() {
    final accountIndex = 0;

    log(LogLevel.info, 'Calling Wallet_address with parameters:');
    log(LogLevel.info, '  accountIndex: $accountIndex');

    final address = _w2Wallet!.address(accountIndex: accountIndex);

    log(LogLevel.info, 'Wallet_address result: $address');

    return address;
  }

  String? getUnusedSubaddress() {
    if (_unusedSubaddressIndex == null) {
      return null;
    }

    var subaddrIndex = _unusedSubaddressIndex!;

    if (_unusedSubaddressIndexIsSupported == false) {
      subaddrIndex -= 1;
    }

    log(LogLevel.info, 'Calling Wallet_address with parameters:');
    log(LogLevel.info, '  accountIndex: 0');
    log(LogLevel.info, '  addressIndex: $subaddrIndex');

    final subaddress = _w2Wallet!.address(accountIndex: 0, addressIndex: subaddrIndex);

    log(LogLevel.info, 'Wallet_address result: $subaddress');

    return subaddress;
  }

  /// Estimates the network fee (in piconero) for a send at [priority] via the
  /// native estimator. Returns null on failure or when fee info isn't cached yet
  Future<int?> estimateFee(
    String destinationAddress,
    double amount, {
    int priority = 0,
    String? amountText,
  }) async {
    if (_w2Wallet == null) return null;

    final amountInt = amountText != null
        ? decimalToBaseUnits(amountText, consts.moneroDecimals).toInt()
        : _w2Wallet!.amountFromDouble(amount);
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    try {
      final fee = await Isolate.run(() {
        // ignore: deprecated_member_use
        return monero.Wallet_estimateTransactionFee(
          Pointer.fromAddress(walletFfiAddr),
          dstAddr: [destinationAddress],
          amounts: [amountInt],
          pendingTransactionPriority: priority,
        );
      });
      // 0 = backend couldn't estimate (never a real fee).
      return fee > 0 ? fee : null;
    } catch (e) {
      log(LogLevel.warn, 'estimateFee failed: $e');
      return null;
    }
  }

  Future<MoneroPendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority = 0,
    String? amountText,
  }) async {
    // Convert the exact decimal string when available; going through double
    // loses precision. Falls back to amountFromDouble when no text is given.
    final amountInt = amountText != null
        ? decimalToBaseUnits(amountText, consts.moneroDecimals).toInt()
        : _w2Wallet!.amountFromDouble(amount);
    final w2WalletFfiAddr = _w2Wallet!.ffiAddress();

    final dstAddr = [destinationAddress];
    final amounts = [amountInt];
    final mixinCount = 15;
    final subaddrAccount = 0;

    log(LogLevel.info, 'Calling Wallet_createTransactionMultDest with parameters:');
    log(LogLevel.info, '  w2WalletFfiAddr: $w2WalletFfiAddr');
    log(LogLevel.info, '  isSweepAll: $isSweepAll');
    log(LogLevel.info, '  dstAddr: $dstAddr');
    log(LogLevel.info, '  amounts: $amounts');
    log(LogLevel.info, '  mixinCount: $mixinCount');
    log(LogLevel.info, '  pendingTransactionPriority: $priority');
    log(LogLevel.info, '  subaddr_account: $subaddrAccount');

    final txPointer = Pointer<Void>.fromAddress(
      await Isolate.run(() {
        // ignore: deprecated_member_use
        return monero.Wallet_createTransactionMultDest(
          Pointer.fromAddress(w2WalletFfiAddr),
          isSweepAll: isSweepAll,
          dstAddr: dstAddr,
          amounts: amounts,
          mixinCount: mixinCount,
          pendingTransactionPriority: priority,
          subaddr_account: subaddrAccount,
        ).address;
      }),
    );

    log(LogLevel.info, 'Wallet_createTransactionMultDest completed');

    final pendingTx = MoneroPendingTransaction(txPointer);

    if (pendingTx.errorString() != '') {
      log(LogLevel.error, 'Failed to create transaction: ${pendingTx.errorString()}');
      throw Exception(pendingTx.errorString());
    }

    return pendingTx;
  }

  Future<void> commitTx(MoneroPendingTransaction tx, String destinationAddress) async {
    final txFfiAddr = tx.ffiAddress();

    final filename = '';
    final overwrite = false;

    log(LogLevel.info, 'Calling PendingTransaction_commit with parameters:');
    log(LogLevel.info, '  filename: $filename');
    log(LogLevel.info, '  overwrite: $overwrite');

    final commitResult = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.PendingTransaction_commit(
        Pointer.fromAddress(txFfiAddr),
        filename: '',
        overwrite: false,
      );
    });

    final status = tx.status();
    log(LogLevel.info, 'PendingTransaction_commit result: $commitResult, status: $status');

    final errorMsg = tx.errorString();

    if (errorMsg != '' && errorMsg != 'Schema expected string') {
      log(LogLevel.error, 'PendingTransaction_commit error: $errorMsg');
      throw FormatException(errorMsg);
    }

    // The broadcast can fail without setting errorString; gate success on the
    // commit result and status too so we don't report a send that didn't happen.
    if (!commitResult || status != 0) {
      log(LogLevel.error, 'PendingTransaction_commit failed: result=$commitResult status=$status');
      throw FormatException('Failed to broadcast transaction.');
    }

    await refresh();
    // Persist so the just-sent unconfirmed tx (held in the wallet's cache, not
    // on-chain yet) survives an app restart before it's mined.
    await store();
    // Reload balances so the spent/locked amount is reflected right away.
    await Future.wait([loadTotalBalance(), loadUnlockedBalance()]);
    await loadTxHistory();
    notifyListeners();
  }

  /// Resolves an OpenAlias domain to a Monero address with end-to-end DNSSEC
  /// validation, over Tor (via the openalias_ffi Rust/hickory resolver). Returns
  /// the validated address, or '' on any failure (incl. Tor unavailable) so the
  /// send flow surfaces a resolve error. OpenAlias never leaves Tor.
  Future<String> resolveOpenAlias(String address) async {
    log(LogLevel.info, 'Resolving OpenAlias over Tor: $address');

    final proxy = await TorSettingsService.sharedInstance.getProxy();
    if (proxy == null) {
      log(LogLevel.warn, 'OpenAlias: Tor proxy unavailable; cannot resolve.');
      return '';
    }

    try {
      final resolved = await OpenAliasFfi.resolve(
        domain: address,
        asset: 'xmr',
        socksPort: proxy.port,
      );

      if (resolved == null || resolved.isEmpty) return '';

      // Only use it if it's a valid Monero address.
      if (_w2Wallet != null && !_w2Wallet!.addressValid(resolved, 0)) {
        log(LogLevel.warn, 'OpenAlias: resolved address failed validation.');
        return '';
      }

      log(LogLevel.info, 'OpenAlias resolved successfully.');
      return resolved;
    } catch (e) {
      log(LogLevel.warn, 'OpenAlias resolution failed: $e');
      return '';
    }
  }

  List<TxDetails> _getTxHistory() {
    final txCount = _w2TxHistory!.count();
    final List<TxDetails> txs = [];

    for (int i = 0; i < txCount; i++) {
      final tx = getTxDetails(i);
      txs.add(tx);
    }

    txs.sort((a, b) {
      return a.timestamp < b.timestamp ? 1 : -1;
    });

    return txs;
  }

  TxDetails getTxDetails(int txIndex) {
    final tx = _w2TxHistory!.transaction(txIndex);
    final direction = tx.direction();
    final hash = tx.hash();
    final amountSent = doubleAmountFromInt(tx.amount());
    final fee = doubleAmountFromInt(tx.fee());
    final timestamp = tx.timestamp();
    final height = tx.blockHeight();
    final confirmations = height > -1 ? _w2Wallet!.blockChainHeight() - height + 1 : 0;
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
