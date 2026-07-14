// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart' show protected;
import 'package:http/http.dart' as http;
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/monero.dart' as monero_ffi;
import 'package:monero/src/wallet2.dart';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/amount_units.dart';
import 'package:skylight_wallet/util/bip39.dart';
import 'package:skylight_wallet/util/cacert.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/util/get_height_by_date.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';
import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/wallets/coins/monero/monero_pending_tx.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

/// Monero implementation of [CryptoWallet].
///
/// Wraps the `monero_c` FFI bindings and translates Monero concepts
/// (subaddresses, polyseed/legacy seeds, OpenAlias resolution, etc.) into
/// the coin-agnostic surface defined by [CryptoWallet].
class MoneroWallet extends CryptoWallet {
  Wallet2WalletManager? _w2WalletManager;
  // Which factory built the cached manager: 'lws' (LWSF) or 'node' (wallet2).
  String? _managerType;
  // Mode the currently-open [_w2Wallet] was loaded for ('lws' | 'node').
  String? _loadedType;

  MoneroWallet() {
    scheduleMicrotask(warmUpWalletManager);
  }

  /// Loads the Monero FFI wallet manager after the first frame so app
  /// startup and unlock stay responsive.
  Future<Wallet2WalletManager> warmUpWalletManager() => _walletManager();

  /// Returns the wallet manager built by the factory matching the current
  /// connection type. LWS uses the LWSF manager (`LWSF_*`); a full node uses
  /// the standard wallet2 manager (`MONERO_*`). Switching types rebuilds the
  /// manager and tears down any wallet opened by the previous one.
  Future<Wallet2WalletManager> _walletManager() async {
    final type = _desiredManagerType;
    if (_w2WalletManager != null && _managerType == type) return _w2WalletManager!;

    // Factory switch: close the wallet the old manager opened before swapping.
    if (_w2WalletManager != null && _w2Wallet != null) {
      _w2WalletManager!.closeWallet(_w2Wallet!, false);
      _w2Wallet = null;
      _w2TxHistory = null;
      _daemonInitialized = false;
      _loadedType = null;
      setIsLoaded(false);
    }

    await Future<void>.delayed(Duration.zero);
    final managerFactory = monero_ffi.Monero().walletManagerFactory();
    _w2WalletManager = type == 'node'
        ? managerFactory.getWalletManager()
        : managerFactory.getLWSFWalletManager();
    _managerType = type;
    return _w2WalletManager!;
  }

  Wallet2Wallet? _w2Wallet;
  Wallet2TransactionHistory? _w2TxHistory;

  // True once Wallet_init has run for the daemon connection. Daemon-dependent
  // FFI calls (Wallet_connected, etc.) abort if invoked before this.
  bool _daemonInitialized = false;

  bool? _serverSupportsSubaddresses;
  int? _unusedSubaddressIndex;
  bool? _unusedSubaddressIndexIsSupported;

  Wallet2Wallet? get w2Wallet => _w2Wallet;
  bool? get serverSupportsSubaddresses => _serverSupportsSubaddresses;
  int? get unusedSubaddressIndex => _unusedSubaddressIndex;
  bool? get unusedSubaddressIndexIsSupported => _unusedSubaddressIndexIsSupported;

  @override
  String get coinSymbol => 'XMR';

  @override
  String get coinName => 'Monero';

  @override
  String get iconAsset => 'assets/icons/monero.svg';

  @override
  int get decimals => 12;

  @override
  int get smallerDigits => 9;

  @override
  int get requiredConfirmations => 10;

  @override
  List<String> get connectionTypeOptions => const ['lws', 'node'];

  /// True when configured to talk to a full Monero node rather than an LWS.
  bool get _isNodeMode => connectionType == 'node';

  /// Manager factory kind the current connection needs ('lws' | 'node').
  String get _desiredManagerType => _isNodeMode ? 'node' : 'lws';

  @override
  String get connectionTypeName => _isNodeMode ? 'Monero node' : 'Monero LWS server';

  @override
  String get connectionAddressExample => 'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String connectionAddressExampleForType(String connectionType) => connectionType == 'node'
      ? 'e.g. node.example.com:18081'
      : 'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String get openAliasAsset => 'xmr';

  // ----- Lifecycle -----

  /// Path of this wallet's file. LWS and full-node modes keep separate cache
  /// files (same keys/seed) so toggling between them doesn't force a rescan;
  /// LWS keeps the original `mywallet_xmr` path for back-compat, the node gets
  /// a `_node` suffix. The migration's [LegacyMoneroWallet] overrides this to
  /// open v1's `mywallet` instead.
  @protected
  Future<String> resolveWalletPath() async {
    final basePath = await getWalletPath(coinSymbol);
    return _isNodeMode ? '${basePath}_node' : basePath;
  }

  @override
  Future<bool> hasExistingWallet() async {
    final wm = await _walletManager();
    final wmFfiAddr = wm.ffiAddress();
    final walletPath = await resolveWalletPath();

    walletLog(LogLevel.info, 'Calling WalletManager_walletExists with parameters:');
    walletLog(LogLevel.info, '  path: $walletPath');

    final exists = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_walletExists(Pointer.fromAddress(wmFfiAddr), walletPath);
    });

    walletLog(LogLevel.info, 'WalletManager_walletExists result: $exists');

    final errorString = wm.errorString();
    if (errorString != '') {
      walletLog(LogLevel.error, 'WalletManager_walletExists error: $errorString');
    }

    return exists;
  }

  @override
  Future<void> openExisting({required String password}) async {
    final wm = await _walletManager();
    final wmFfiAddr = wm.ffiAddress();
    final walletPath = await resolveWalletPath();

    walletLog(LogLevel.info, 'Calling WalletManager_openWallet with parameters:');
    walletLog(LogLevel.info, '  path: $walletPath');
    walletLog(LogLevel.info, '  password: <hidden>');

    final w2WalletFfiAddr = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_openWallet(
        Pointer.fromAddress(wmFfiAddr),
        path: walletPath,
        password: password,
      ).address;
    });

    final w2Wallet = monero_ffi.MoneroWallet(Pointer<Void>.fromAddress(w2WalletFfiAddr));

    if (w2Wallet.errorString() != '') {
      final errorMsg = 'WalletManager_openWallet error: ${w2Wallet.errorString()}';
      walletLog(LogLevel.error, errorMsg);
      throw Exception(errorMsg);
    }

    walletLog(LogLevel.info, 'WalletManager_openWallet completed');

    _w2Wallet = w2Wallet;
    _w2TxHistory = _w2Wallet!.history();
    _loadedType = _desiredManagerType;

    await loadPersistedSubaddressSupport();
    await loadPersistedUnusedSubaddressIndex();
    setIsLoaded(true);
  }

  @override
  Future<void> restoreFromMasterSeed({
    required String bip39Mnemonic,
    required DateTime restoreDate,
    required String password,
  }) async {
    if (password == '') {
      throw Exception('Password should not be empty.');
    }

    if (!bip39.validateMnemonic(bip39Mnemonic)) {
      throw Exception('Invalid mnemonic.');
    }

    // Off the UI thread: mnemonicToSeed (PBKDF2) here is the sync prefix that
    // would otherwise block before the restore spinner can paint.
    final legacyMnemonic = await Isolate.run(() => getLegacySeedFromBip39(bip39Mnemonic));
    final restoreHeight = getHeightByDate(date: restoreDate);

    walletLog(LogLevel.info, 'Using blockchain height: $restoreHeight');

    final wallet = await _walletFromLegacySeed(
      mnemonic: legacyMnemonic,
      restoreHeight: restoreHeight,
      password: password,
    );

    final hasError =
        (wallet.errorString() != '' || wallet.status() != 0) &&
        !wallet.errorString().contains('No response from HTTP server');

    if (hasError) {
      if (wallet.errorString().contains('word list failed verification') ||
          wallet.errorString().contains('Failed polyseed decode')) {
        throw Exception('Invalid mnemonic.');
      }

      walletLog(LogLevel.error, 'Error restoring from mnemonic: ${wallet.errorString()}');
      throw Exception('Error restoring from mnemonic: ${wallet.errorString()}');
    }

    _w2Wallet = wallet;
    _w2TxHistory = _w2Wallet!.history();

    await SharedPreferencesService.set<int>(prefKey('walletRestoreHeight'), restoreHeight);
    _loadedType = _desiredManagerType;

    setIsLoaded(true);
    await store();
  }

  @override
  Future<bool> needsRebuildForCurrentConnection() async {
    // The open wallet object is bound to the factory/file of the mode it was
    // loaded for; a server-kind switch must re-open the matching file (which
    // is recovered from the seed if it doesn't exist yet).
    return _w2Wallet != null && _loadedType != _desiredManagerType;
  }

  Future<monero_ffi.MoneroWallet> _walletFromLegacySeed({
    required String mnemonic,
    required int restoreHeight,
    required String password,
  }) async {
    final wm = await _walletManager();
    final wmFfiAddr = wm.ffiAddress();
    final walletPath = await resolveWalletPath();

    walletLog(LogLevel.info, 'Calling WalletManager_recoveryWallet with parameters:');
    walletLog(LogLevel.info, '  mnemonic: <hidden>');
    walletLog(LogLevel.info, '  restoreHeight: $restoreHeight');
    walletLog(LogLevel.info, '  password: <hidden>');
    walletLog(LogLevel.info, '  path: $walletPath');

    final walletFfiAddr = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_recoveryWallet(
        Pointer.fromAddress(wmFfiAddr),
        mnemonic: mnemonic,
        seedOffset: '',
        restoreHeight: restoreHeight,
        password: password,
        path: walletPath,
      ).address;
    });

    walletLog(LogLevel.info, 'WalletManager_recoveryWallet completed');

    return monero_ffi.MoneroWallet(Pointer<Void>.fromAddress(walletFfiAddr));
  }

  @override
  Future<bool> store() async {
    if (_w2Wallet == null) return false;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    walletLog(LogLevel.info, 'Calling Wallet_store');

    final result = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_store(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    walletLog(LogLevel.info, 'Wallet_store result: $result');
    return result;
  }

  @override
  void dispose() {
    // Close the native wallet so its decrypted keys and background threads
    // aren't left in native memory after this object is gone.
    if (_w2Wallet != null && _w2WalletManager != null) {
      _w2WalletManager!.closeWallet(_w2Wallet!, false);
      _w2Wallet = null;
      _w2TxHistory = null;
      _daemonInitialized = false;
    }
    super.dispose();
  }

  @override
  Future<void> deleteFiles() async {
    if (_w2Wallet != null) {
      final wm = await _walletManager();
      wm.closeWallet(_w2Wallet!, false);
      _w2Wallet = null;
      _w2TxHistory = null;
      _daemonInitialized = false;
    }

    // Remove both mode files (LWS `mywallet_xmr*` and node `mywallet_xmr_node*`)
    // plus the companion `.keys` / `.address.txt` Monero writes alongside each.
    final currentPath = await resolveWalletPath();
    final lwsBase = currentPath.endsWith('_node')
        ? currentPath.substring(0, currentPath.length - 5)
        : currentPath;
    for (final b in {lwsBase, '${lwsBase}_node'}) {
      for (final p in [b, '$b.keys', '$b.address.txt']) {
        final file = File(p);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  @override
  Future<void> clearPersistedState() async {
    await super.clearPersistedState();
    await SharedPreferencesService.remove(prefKey('serverSupportsSubaddresses'));
    await SharedPreferencesService.remove(prefKey('unusedSubaddressIndex'));
    await SharedPreferencesService.remove(prefKey('unusedSubaddressIndexIsSupported'));
    _serverSupportsSubaddresses = null;
    _unusedSubaddressIndex = null;
    _unusedSubaddressIndexIsSupported = null;
  }

  // ----- Daemon / refresh -----

  @override
  Future<void> connectToDaemonImpl({
    required String address,
    String? proxyPort,
    required bool useSsl,
  }) async {
    if (_w2Wallet == null) throw Exception('w2wallet is null');

    // The open wallet object is bound to the factory of the mode it was opened
    // in (LWS vs node). Connecting before the manager is rebuilt for the new
    // mode would call Wallet_init with a mismatched lightWallet flag and abort.
    if (_loadedType != _desiredManagerType) {
      walletLog(
        LogLevel.warn,
        'Skipping connect: loaded as "$_loadedType" but connection needs "$_desiredManagerType"; awaiting rebuild',
      );
      return;
    }

    if (Platform.isAndroid) {
      // Addresses SSL certificate verification issues on Android.
      final cacertFile = await getCacertFile();
      _w2Wallet!.setCaFilePath(cacertFile.path);
    }

    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final daemonAddress = '${useSsl ? 'https://' : 'http://'}$address';
    final proxyAddress = proxyPort != null && proxyPort != '' ? '127.0.0.1:$proxyPort' : '';
    final lightWallet = !_isNodeMode;

    walletLog(LogLevel.info, 'Calling Wallet_init with parameters:');
    walletLog(LogLevel.info, '  daemonAddress: $daemonAddress');
    walletLog(LogLevel.info, '  proxyAddress: $proxyAddress');
    walletLog(LogLevel.info, '  useSsl: $useSsl');
    walletLog(LogLevel.info, '  lightWallet: $lightWallet');

    // Run the whole connect sequence in a single isolate hop (instead of one
    // per native call) and time each step so a slow daemon handshake is
    // attributable. A full node also needs its background refresh thread
    // kicked here; LWS lets the server scan, so it skips that.
    final isNode = _isNodeMode;
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

    walletLog(
      LogLevel.info,
      'Wallet connect timings: init ${r.initMs}ms (result ${r.initResult}), '
      'connectToDaemon ${r.connectMs}ms (result ${r.connectResult}), '
      'startRefresh ${r.refreshMs}ms',
    );

    _daemonInitialized = true;

    final connectError = _w2Wallet!.errorString();
    if (connectError != '') {
      walletLog(LogLevel.warn, 'Wallet_connectToDaemon error: $connectError');
    }
  }

  @override
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
    walletLog(LogLevel.info, 'Probing LWS server: $url (tor=$useTor, proxyPort=$proxyPort)');

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

    // LWS responds with 500 to an unauthenticated POST to
    // /get_address_info. Anything else means we're not talking to a
    // real LWS endpoint.
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
    walletLog(LogLevel.info, 'Probing Monero node: $url (tor=$useTor, proxyPort=$proxyPort)');

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

  @override
  Future<bool> getIsConnected() async {
    if (_w2Wallet == null || !_daemonInitialized) return false;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    final connected = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connected(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    return connected != 0;
  }

  @override
  Future<void> refresh() async {
    if (_w2Wallet == null || _w2TxHistory == null || !_daemonInitialized) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final historyFfiAddr = _w2TxHistory!.ffiAddress();

    if (_isNodeMode) {
      // Background refresh thread does the block scanning; just make sure it's
      // running and pull the latest tx-history view from the wallet's cache.
      walletLog(LogLevel.info, 'Ensuring full-node refresh thread + history refresh');
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

    walletLog(LogLevel.info, 'Calling Wallet_refresh and TransactionHistory_refresh');

    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_refresh(Pointer.fromAddress(walletFfiAddr)),
    );

    await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.TransactionHistory_refresh(Pointer.fromAddress(historyFfiAddr)),
    );

    walletLog(LogLevel.info, 'Wallet refresh methods completed successfully');
  }

  @override
  Future<void> pollSyncStatus() async {
    // Only the full node flips "synchronized" off its background thread; LWS
    // sync state is settled by the blocking refresh in the 20s loop.
    if (!_isNodeMode || _w2Wallet == null) return;

    final wasSynced = isSynced;
    await loadIsSynced();
    await loadSyncedHeight();

    // Just caught up: pull fresh balances + tx now rather than waiting for the
    // next refresh cycle.
    if (!wasSynced && isSynced) {
      await loadAllStats();
    }
  }

  @override
  Future<void> loadIsSynced() async {
    if (_w2Wallet == null || !_daemonInitialized) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    walletLog(LogLevel.info, 'Calling Wallet_synchronized:');

    final synced = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_synchronized(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    walletLog(LogLevel.info, 'Wallet_synchronized result: $synced');

    if (_isNodeMode && !synced) {
      // Surface scan progress (wallet height vs daemon tip) while syncing.
      final heights = await Isolate.run(() {
        // ignore: deprecated_member_use
        final wallet = monero.Wallet_blockChainHeight(Pointer<Void>.fromAddress(walletFfiAddr));
        // ignore: deprecated_member_use
        final daemon = monero.Wallet_daemonBlockChainHeight(
          Pointer<Void>.fromAddress(walletFfiAddr),
        );
        return (wallet: wallet, daemon: daemon);
      });
      walletLog(
        LogLevel.info,
        'Node sync progress: wallet ${heights.wallet} / daemon ${heights.daemon}',
      );
    }

    setIsSynced(synced);
  }

  @override
  Future<void> loadSyncedHeight() async {
    if (_w2Wallet == null || !_daemonInitialized) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    walletLog(LogLevel.info, 'Calling Wallet_blockChainHeight:');

    final height = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_blockChainHeight(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    walletLog(LogLevel.info, 'Wallet_blockChainHeight result: $height');
    setSyncedHeight(height);
  }

  @override
  Future<void> loadTotalBalance() async {
    if (_w2Wallet == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final accountIndex = 0;

    walletLog(LogLevel.info, 'Calling Wallet_balance with parameters:');
    walletLog(LogLevel.info, '  accountIndex: $accountIndex');

    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_balance(
        Pointer<Void>.fromAddress(walletFfiAddr),
        accountIndex: accountIndex,
      ),
    );

    walletLog(LogLevel.info, 'Wallet_balance result: $amount');
    setTotalBalanceBaseUnits(BigInt.from(amount));
  }

  @override
  Future<void> loadUnlockedBalance() async {
    if (_w2Wallet == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final accountIndex = 0;

    walletLog(LogLevel.info, 'Calling Wallet_unlockedBalance with parameters:');
    walletLog(LogLevel.info, '  accountIndex: $accountIndex');

    final amount = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_unlockedBalance(
        Pointer<Void>.fromAddress(walletFfiAddr),
        accountIndex: accountIndex,
      ),
    );

    walletLog(LogLevel.info, 'Wallet_unlockedBalance result: $amount');
    setUnlockedBalanceBaseUnits(BigInt.from(amount));
  }

  @override
  Future<int> getCurrentHeight() async {
    final wm = await _walletManager();
    final wmFfiAddr = wm.ffiAddress();

    walletLog(LogLevel.info, 'Calling WalletManager_blockchainHeight');

    final height = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_blockchainHeight(Pointer.fromAddress(wmFfiAddr));
    });

    walletLog(LogLevel.info, 'WalletManager_blockchainHeight result: $height');
    return height;
  }

  @override
  Future<int> getRestoreHeight() async {
    if (_w2Wallet == null) {
      return await SharedPreferencesService.get<int>(prefKey('walletRestoreHeight')) ?? 0;
    }

    walletLog(LogLevel.info, 'Calling Wallet_getRefreshFromBlockHeight');
    final w2RestoreHeight = _w2Wallet!.getRefreshFromBlockHeight();
    walletLog(LogLevel.info, 'Wallet_getRefreshFromBlockHeight result: $w2RestoreHeight');

    if (w2RestoreHeight > 0) {
      return w2RestoreHeight;
    }

    return await SharedPreferencesService.get<int>(prefKey('walletRestoreHeight')) ?? 0;
  }

  @override
  List<TxDetails> readTxHistory() {
    if (_w2TxHistory == null || _w2Wallet == null) return [];

    final txCount = _w2TxHistory!.count();
    // Hoist the chain-tip FFI call out of the per-tx loop (invariant).
    final chainHeight = _w2Wallet!.blockChainHeight();
    final List<TxDetails> txs = [];

    for (int i = 0; i < txCount; i++) {
      txs.add(_buildTxDetails(i, chainHeight));
    }

    txs.sort((a, b) => a.timestamp < b.timestamp ? 1 : -1);
    return txs;
  }

  TxDetails _buildTxDetails(int txIndex, int chainHeight) {
    final tx = _w2TxHistory!.transaction(txIndex);
    final direction = tx.direction();
    final hash = tx.hash();
    final amountSent = doubleAmountFromInt(tx.amount());
    final fee = doubleAmountFromInt(tx.fee());
    final timestamp = tx.timestamp();
    final rawHeight = tx.blockHeight();
    final isUnconfirmed = rawHeight <= 0;
    final height = isUnconfirmed ? -1 : rawHeight;
    final confirmations = isUnconfirmed ? 0 : (chainHeight - rawHeight).clamp(0, chainHeight);
    final key = _w2Wallet!.getTxKey(txid: hash);

    final List<TxRecipient> recipients = [];
    final recipientsCount = tx.transfers_count();
    final accountIndex = tx.subaddrAccount();
    final subaddrIndexList = tx
        .subaddrIndex()
        .split(", ")
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    for (int i = 0; i < recipientsCount; i++) {
      final address = tx.transfers_address(i);
      final amount = doubleAmountFromInt(tx.transfers_amount(i));
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

  // ----- Send / receive -----

  @override
  String getPrimaryAddress() {
    final accountIndex = 0;

    walletLog(LogLevel.info, 'Calling Wallet_address with parameters:');
    walletLog(LogLevel.info, '  accountIndex: $accountIndex');

    final address = _w2Wallet!.address(accountIndex: accountIndex);

    walletLog(LogLevel.info, 'Wallet_address result: $address');
    return address;
  }

  @override
  String? getReceiveAddress() => getUnusedSubaddress();

  @override
  bool isAddressValid(String address) {
    if (_w2Wallet == null) return false;
    return _w2Wallet!.addressValid(address, 0);
  }

  String? getUnusedSubaddress() {
    if (_unusedSubaddressIndex == null) return null;

    var subaddrIndex = _unusedSubaddressIndex!;

    if (_unusedSubaddressIndexIsSupported == false) {
      subaddrIndex -= 1;
    }

    walletLog(LogLevel.info, 'Calling Wallet_address with parameters:');
    walletLog(LogLevel.info, '  accountIndex: 0');
    walletLog(LogLevel.info, '  addressIndex: $subaddrIndex');

    final subaddress = _w2Wallet!.address(accountIndex: 0, addressIndex: subaddrIndex);

    walletLog(LogLevel.info, 'Wallet_address result: $subaddress');
    return subaddress;
  }

  @override
  Future<PendingTransaction> createTx(
    String destinationAddress,
    double amount,
    String? amountText,
    bool isSweepAll, {
    int priority = 0,
  }) async {
    final amountInt = amountText != null
        ? decimalToBaseUnits(amountText, decimals).toInt()
        : _w2Wallet!.amountFromDouble(amount);

    final walletFfiAddr = _w2Wallet!.ffiAddress();

    final dstAddr = [destinationAddress];
    final amounts = [amountInt];
    final mixinCount = 15;
    final subaddrAccount = 0;

    walletLog(LogLevel.info, 'Calling Wallet_createTransactionMultDest with parameters:');
    walletLog(LogLevel.info, '  walletFfiAddr: $walletFfiAddr');
    walletLog(LogLevel.info, '  isSweepAll: $isSweepAll');
    walletLog(LogLevel.info, '  dstAddr: $dstAddr');
    walletLog(LogLevel.info, '  amounts: $amounts');
    walletLog(LogLevel.info, '  mixinCount: $mixinCount');
    walletLog(LogLevel.info, '  pendingTransactionPriority: $priority');
    walletLog(LogLevel.info, '  subaddr_account: $subaddrAccount');

    final txPointer = Pointer<Void>.fromAddress(
      await Isolate.run(() {
        // ignore: deprecated_member_use
        return monero.Wallet_createTransactionMultDest(
          Pointer.fromAddress(walletFfiAddr),
          isSweepAll: isSweepAll,
          dstAddr: dstAddr,
          amounts: amounts,
          mixinCount: mixinCount,
          pendingTransactionPriority: priority,
          subaddr_account: subaddrAccount,
        ).address;
      }),
    );

    walletLog(LogLevel.info, 'Wallet_createTransactionMultDest completed');

    final pendingTx = monero_ffi.MoneroPendingTransaction(txPointer);

    if (pendingTx.errorString() != '') {
      walletLog(LogLevel.error, 'Failed to create transaction: ${pendingTx.errorString()}');
      throw Exception(pendingTx.errorString());
    }

    return MoneroPendingTx(pendingTx);
  }

  @override
  Future<void> commitTx(PendingTransaction tx, String destinationAddress) async {
    if (tx is! MoneroPendingTx) {
      throw ArgumentError('MoneroWallet.commitTx requires a MoneroPendingTx');
    }
    final txFfiAddr = tx.raw.ffiAddress();

    walletLog(LogLevel.info, 'Calling PendingTransaction_commit with parameters:');
    walletLog(LogLevel.info, '  filename: ');
    walletLog(LogLevel.info, '  overwrite: false');

    final commitResult = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.PendingTransaction_commit(
        Pointer.fromAddress(txFfiAddr),
        filename: '',
        overwrite: false,
      );
    });

    final status = tx.raw.status();
    walletLog(LogLevel.info, 'PendingTransaction_commit result: $commitResult, status: $status');

    final errorMsg = tx.errorString;
    if (errorMsg != '' && errorMsg != 'Schema expected string') {
      walletLog(LogLevel.error, 'PendingTransaction_commit error: $errorMsg');
      throw FormatException(errorMsg);
    }

    // The broadcast can fail without setting errorString; gate success on the
    // commit result and status too so we don't report a send that didn't happen.
    if (!commitResult || status != 0) {
      walletLog(
        LogLevel.error,
        'PendingTransaction_commit failed: result=$commitResult status=$status',
      );
      throw FormatException('Failed to broadcast transaction.');
    }

    await refresh();
    // Persist so the just-sent unconfirmed tx (held in the wallet's cache,
    // not on-chain yet) survives an app restart before it's mined.
    await store();
    // Reload balances so the spent/locked amount is reflected right away.
    await Future.wait([loadTotalBalance(), loadUnlockedBalance()]);
    await loadTxHistory();
    notifyListeners();
    // Also refresh the cached display snapshot so the pending tx + reduced
    // balance show immediately on next launch, before the sync re-reads them.
    await persistWalletSnapshot();
  }

  // ----- Subaddress support tracking -----

  Future<void> loadPersistedSubaddressSupport() async {
    _serverSupportsSubaddresses = await SharedPreferencesService.get<bool>(
      prefKey('serverSupportsSubaddresses'),
    );
  }

  Future<void> loadPersistedUnusedSubaddressIndex() async {
    _unusedSubaddressIndex = await SharedPreferencesService.get<int>(
      prefKey('unusedSubaddressIndex'),
    );
    _unusedSubaddressIndexIsSupported = await SharedPreferencesService.get<bool>(
      prefKey('unusedSubaddressIndexIsSupported'),
    );
  }

  Future<void> loadSubaddressSupport() async {
    if (_isNodeMode) {
      _serverSupportsSubaddresses = true;
      await SharedPreferencesService.set<bool>(prefKey('serverSupportsSubaddresses'), true);
      return;
    }

    try {
      final isSupported = await isSubaddressSupported(1);
      _serverSupportsSubaddresses = isSupported;

      await SharedPreferencesService.set<bool>(
        prefKey('serverSupportsSubaddresses'),
        _serverSupportsSubaddresses!,
      );
    } catch (_) {
      // intentionally swallow: subaddress support check is best-effort
    }
  }

  Future<void> loadUnusedSubaddressIndex() async {
    final history = readTxHistory();

    final Set<int> usedIndexes = {};
    for (final tx in history) {
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

    if (_unusedSubaddressIndex == nextSubaddrIndex) return;

    if (_isNodeMode) {
      _unusedSubaddressIndex = nextSubaddrIndex;
      _unusedSubaddressIndexIsSupported = true;
      await SharedPreferencesService.set<int>(
        prefKey('unusedSubaddressIndex'),
        _unusedSubaddressIndex!,
      );
      await SharedPreferencesService.set<bool>(prefKey('unusedSubaddressIndexIsSupported'), true);
      notifyListeners();
      return;
    }

    try {
      final isSupported = await isSubaddressSupported(nextSubaddrIndex);
      _unusedSubaddressIndex = nextSubaddrIndex;
      _unusedSubaddressIndexIsSupported = isSupported;

      await SharedPreferencesService.set<int>(
        prefKey('unusedSubaddressIndex'),
        _unusedSubaddressIndex!,
      );
      await SharedPreferencesService.set<bool>(
        prefKey('unusedSubaddressIndexIsSupported'),
        _unusedSubaddressIndexIsSupported!,
      );

      notifyListeners();
    } catch (_) {
      // intentionally swallow: subaddress support check is best-effort
    }
  }

  Future<bool> isSubaddressSupported(int subaddrIndex) async {
    final proto = connectionUseSsl ? 'https' : 'http';
    final url = Uri.parse('$proto://$connectionAddress/upsert_subaddrs');
    final primaryAddress = getPrimaryAddress();
    final viewKey = _w2Wallet!.secretViewKey();
    final subaddrs = [
      {
        'key': 0,
        'value': [
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

    walletLog(LogLevel.info, 'Checking subaddress support:');
    walletLog(LogLevel.info, '  url: $url');
    walletLog(LogLevel.info, '  primaryAddress: $primaryAddress');
    walletLog(LogLevel.info, '  viewKey: <hidden>');
    walletLog(LogLevel.info, '  subaddrs: $subaddrs');
    walletLog(LogLevel.info, '  getAll: $getAll');

    ({InternetAddress host, int port})? proxyInfo;
    if (connectionUseTor) {
      proxyInfo = await TorSettingsService.sharedInstance.getProxy();
      if (proxyInfo == null) {
        throw Exception('Connection requires Tor but no Tor proxy is available.');
      }
    } else if (connectionProxyPort.isNotEmpty) {
      final port = int.tryParse(connectionProxyPort);
      if (port != null) proxyInfo = (host: InternetAddress.loopbackIPv4, port: port);
    }

    var httpStatus = 0;

    for (int i = 0; i < 3; i++) {
      try {
        if (proxyInfo != null) {
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
          walletLog(LogLevel.warn, 'Failed to check subaddress support after ${i + 1} attempts.');
          walletLog(LogLevel.warn, 'Error: $e');
          rethrow;
        }
      }
    }

    final result = httpStatus == 200;

    walletLog(
      LogLevel.info,
      'Subaddress support check result for subaddress $subaddrIndex: $result (status: $httpStatus)',
    );

    return result;
  }

  // ----- Hooks -----

  @override
  Future<void> load() async {
    if (!isActive) return;
    await loadPersistedSubaddressSupport();
    await loadPersistedUnusedSubaddressIndex();
    await super.load();
    await loadSubaddressSupport();
    await loadUnusedSubaddressIndex();
  }

  @override
  Future<void> onTxHistoryGrew() async {
    await loadUnusedSubaddressIndex();
  }
}
