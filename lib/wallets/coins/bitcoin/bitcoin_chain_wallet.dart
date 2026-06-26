import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/util/wallet_file_crypto.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_coin_selection.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_fees.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_pending_tx.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_wallet_open.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/electrum_client.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

/// BIP84 (P2WPKH) Bitcoin-family wallet backed by a user-supplied Electrum server.
///
/// Implemented by mainnet [`BitcoinWallet`](bitcoin_wallet.dart) and testnet
/// [`BitcoinTestnetWallet`](bitcoin_testnet_wallet.dart) via different paths
/// (`m/84'/0'/0'` vs `m/84'/1'/0'`).
class BitcoinChainWallet extends CryptoWallet {
  static const int _gapLimit = 10;
  static const int _satsPerBtc = 100000000;
  static const double _defaultFeeRateSatVb = 5;

  static const int _externalChain = 0;
  static const int _internalChain = 1;

  // P2WPKH virtual sizes (vbytes) for fee/selection estimates.
  static const int _txOverheadVsize = 10;
  static const int _inputVsize = 68;
  static const int _outputVsize = 31;
  static const int _dustThresholdSats = 546;

  // TEMP TESTING TOGGLE. Flip back to false before shipping.
  // When true: skip persisting/loading the address cache (omits the
  // `addresses` key from the wallet file) and the verbose-tx blob cache
  // (SharedPreferences). Every open re-derives and every refresh re-fetches.
  static const bool _disableCache = false;

  BitcoinChainWallet({
    required BitcoinNetwork network,
    required String bip84AccountPath,
    required String coinSymbol,
    required String coinName,
    required String iconAsset,
    required String connectionAddressExample,
    required bool isTestnet,
  }) : _network = network,
       _bip84AccountPath = bip84AccountPath,
       _coinSymbol = coinSymbol,
       _coinName = coinName,
       _iconAsset = iconAsset,
       _connectionAddressExample = connectionAddressExample,
       _isTestnet = isTestnet,
       _client = ElectrumClient(coinSymbol: coinSymbol) {
    _client.onConnectionChanged = (connected) {
      if (!connected) {
        // Server-side subscriptions die with the socket; force re-subscribe
        // on reconnect. _statusByScripthash kept so unchanged scripthashes
        // skip the refetch when subscribe returns the same status.
        _subscribedScripthashes.clear();
        // Retry fee methods against whatever server we reconnect to.
        _feeHistogramUnavailable = false;
        _estimateFeeUnavailable = false;
      }
    };
  }

  final BitcoinNetwork _network;
  final String _bip84AccountPath;
  final String _coinSymbol;
  final String _coinName;
  final String _iconAsset;
  final String _connectionAddressExample;
  final bool _isTestnet;
  final ElectrumClient _client;

  // ----- In-memory wallet state (set once on open/restore) -----

  String? _mnemonic;
  Bip32Slip10Secp256k1? _accountHd;
  // Pre-derived account xprv carried over from the open isolate. Lets
  // _requireAccountHd reconstruct via fromExtendedKey (cheap) instead of
  // re-running mnemonicToSeed + path derive (~750ms cold).
  String? _accountXprv;
  // Per-chain HD nodes cached so _generateAddress pays only one child
  // derive per address. Cleared with [_accountHd].
  Bip32Slip10Secp256k1? _externalHd;
  Bip32Slip10Secp256k1? _internalHd;
  DateTime? _restoreDate;

  // ----- Cached chain state (rebuilt on refresh) -----

  /// All HD addresses we have ever generated, in deterministic order.
  /// Index in this list does NOT match the BIP32 key index; use
  /// [_BtcAddress.index] for that. Receive/change chains are tracked
  /// separately via [_BtcAddress.isChange].
  final List<_BtcAddress> _addresses = [];

  /// Latest server-reported scripthash state, keyed by scripthash.
  final Map<String, _ScripthashState> _scripthashState = {};

  /// Scripthashes we've called `blockchain.scripthash.subscribe` on against
  /// the current socket. Cleared on disconnect so reconnect re-subscribes.
  final Set<String> _subscribedScripthashes = {};

  /// Latest known status hash per scripthash. Diffed against
  /// [_ScripthashState.statusAtFetch] to decide whether cached state is
  /// stale. Preserved across reconnects so brief outages don't cause
  /// pointless refetches.
  final Map<String, String?> _statusByScripthash = {};

  /// Debounce + dedupe for push-driven refresh. A burst of scripthash
  /// notifications coalesces into a single refresh + stats run.
  Timer? _pushDebounce;
  bool _pushPending = false;
  bool _pushHandlerActive = false;

  /// Re-entry guard for [refresh] so the periodic timer and a push-driven
  /// run don't interleave their gap-limit walks.
  bool _refreshing = false;

  /// Set when a fee RPC times out or errors so we don't re-wait on it every
  /// send. Reset on reconnect.
  bool _feeHistogramUnavailable = false;
  bool _estimateFeeUnavailable = false;

  /// Off by default: most public Electrum servers reject verbose tx
  /// responses. The verbose path stays in the code for self-hosted Fulcrum
  /// users; flip this true if you know your server supports it.
  bool _serverSupportsVerboseTx = false;

  /// Cache of fully-decoded transactions keyed by txid; populated lazily
  /// by `loadTxHistory`.
  final Map<String, _TxCacheEntry> _txCache = {};

  /// Block timestamps keyed by height, from header subscription or
  /// `blockchain.block.header`.
  final Map<int, int> _blockTimeByHeight = {};

  int _bestHeight = 0;
  int _nextReceiveIndex = 0;
  int _nextChangeIndex = 0;

  // ----- CryptoWallet metadata -----

  @override
  String get coinSymbol => _coinSymbol;

  @override
  String get coinName => _coinName;

  @override
  String get iconAsset => _iconAsset;

  @override
  int get decimals => 8;

  @override
  int get smallerDigits => 3;

  @override
  int get requiredConfirmations => 1;

  @override
  bool get isTestnet => _isTestnet;

  @override
  String get connectionTypeName => 'Electrum server';

  @override
  String get connectionAddressExample => _connectionAddressExample;

  // ----- Persistence -----

  Future<File> _walletFile() async => File(await getWalletPath(coinSymbol));

  @override
  Future<bool> hasExistingWallet() async {
    final file = await _walletFile();
    if (!await file.exists()) return false;
    final blob = (await file.readAsString()).trim();
    return WalletFileCrypto.isValidEncryptedBlobBase64(blob);
  }

  @override
  Future<void> openExisting({required String password}) async {
    final total = Stopwatch()..start();

    final fileTimer = Stopwatch()..start();
    final file = await _walletFile();
    final blob = (await file.readAsString()).trim();
    fileTimer.stop();

    final bip84AccountPath = _bip84AccountPath;
    final coinSymbol = _coinSymbol;
    final externalChain = _externalChain;
    final internalChain = _internalChain;
    final isTestnet = _isTestnet;

    final isolateTimer = Stopwatch()..start();
    final result = await Isolate.run(
      () => openBitcoinWalletFromEncryptedBlob(
        blob: blob,
        password: password,
        bip84AccountPath: bip84AccountPath,
        coinSymbol: coinSymbol,
        isTestnet: isTestnet,
        externalChain: externalChain,
        internalChain: internalChain,
      ),
    );
    isolateTimer.stop();

    final applyTimer = Stopwatch()..start();
    _applyOpenResult(result.open, password);
    applyTimer.stop();

    total.stop();
    walletLog(
      LogLevel.info,
      'openExisting in ${total.elapsedMilliseconds}ms '
      '(file ${fileTimer.elapsedMilliseconds}ms, '
      'isolate ${isolateTimer.elapsedMilliseconds}ms '
      '[decrypt ${result.decryptMs}ms, derive ${result.deriveMs}ms, '
      '${result.open.addresses.length} addrs], '
      'apply ${applyTimer.elapsedMilliseconds}ms)',
    );
  }

  void _applyOpenResult(BitcoinWalletOpenResult result, String password) {
    _mnemonic = result.mnemonic;
    _restoreDate = result.restoreDateIso != null ? DateTime.tryParse(result.restoreDateIso!) : null;
    _nextReceiveIndex = result.nextReceiveIndex;
    _nextChangeIndex = result.nextChangeIndex;
    _addresses
      ..clear()
      ..addAll(
        result.addresses.map(
          (a) => _BtcAddress(
            index: a.index,
            isChange: a.isChange,
            address: a.address,
            scriptHash: a.scriptHash,
          ),
        ),
      );
    // Clear first so the carried xprv survives (used by _requireAccountHd).
    _clearHdCache();
    _accountXprv = result.accountXprv;
    _lastPassword = password;
    setIsLoaded(true);
  }

  /// Invalidates the account/chain HD nodes and the cached xprv string.
  void _clearHdCache() {
    _accountHd = null;
    _accountXprv = null;
    _externalHd = null;
    _internalHd = null;
  }

  Bip32Slip10Secp256k1 _requireAccountHd() {
    if (_accountHd != null) return _accountHd!;
    if (_mnemonic == null) {
      throw StateError('Wallet is not loaded.');
    }
    final timer = Stopwatch()..start();
    final xprv = _accountXprv;
    final hd = xprv != null
        ? Bip32Slip10Secp256k1.fromExtendedKey(xprv)
        : _deriveAccountHd(_mnemonic!);
    timer.stop();
    walletLog(
      LogLevel.info,
      'accountHd ${xprv != null ? 'import-xprv' : 'derive'} '
      'in ${timer.elapsedMilliseconds}ms',
    );
    return _accountHd = hd;
  }

  @override
  Future<void> restoreFromMasterSeed({
    required String bip39Mnemonic,
    required DateTime restoreDate,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw Exception('Password should not be empty.');
    }
    if (!bip39.validateMnemonic(bip39Mnemonic)) {
      throw Exception('Invalid mnemonic.');
    }

    final bip84AccountPath = _bip84AccountPath;
    final coinSymbol = _coinSymbol;
    final gapLimit = _gapLimit;
    final externalChain = _externalChain;
    final internalChain = _internalChain;
    final isTestnet = _isTestnet;
    final restoreDateIso = restoreDate.toIso8601String();

    final result = await Isolate.run(
      () => bootstrapBitcoinWalletFromMnemonic(
        mnemonic: bip39Mnemonic,
        bip84AccountPath: bip84AccountPath,
        coinSymbol: coinSymbol,
        isTestnet: isTestnet,
        gapLimit: gapLimit,
        externalChain: externalChain,
        internalChain: internalChain,
        restoreDateIso: restoreDateIso,
      ),
    );

    _applyOpenResult(result, password);
    await _persistTo(password);
  }

  /// Last password used for encryption. Required so `store()` (called from
  /// the periodic refresh task on the base class) can re-seal the file
  /// without re-prompting the user. Set in [openExisting] /
  /// [restoreFromMasterSeed].
  String? _lastPassword;

  Future<void> _persistTo(String password) async {
    _lastPassword = password;
    final file = await _walletFile();
    final json = jsonEncode({
      'mnemonic': _mnemonic,
      'next_receive_index': _nextReceiveIndex,
      'next_change_index': _nextChangeIndex,
      'restore_date_iso': _restoreDate?.toIso8601String(),
      // Cache + xprv omitted when [_disableCache] is set so reopens re-derive
      // from the mnemonic instead of loading the cached set.
      if (!_disableCache && _accountXprv != null) 'account_xprv': _accountXprv,
      if (!_disableCache)
        'addresses': [
          for (final a in _addresses)
            {
              'index': a.index,
              'is_change': a.isChange,
              'address': a.address,
              'script_hash': a.scriptHash,
            },
        ],
    });
    await file.writeAsString(await WalletFileCrypto.encryptToBase64(json, password));
  }

  @override
  Future<bool> store() async {
    if (_mnemonic == null || _lastPassword == null) return false;
    try {
      await _persistTo(_lastPassword!);
      return true;
    } catch (e) {
      walletLog(LogLevel.warn, 'store failed: $e');
      return false;
    }
  }

  /// Pref key for the cached raw-tx blobs. Lives next to the base class's
  /// `cachedTxHistory` (which holds the rendered list) and lets
  /// [loadTxHistory] skip refetching every confirmed tx on every unlock.
  String get _txCachePrefKey => prefKey('cachedTxBlobs');

  /// Pref key for the persisted per-scripthash state (balance + history +
  /// unspent + status hash). Restored on reopen so [refresh] can diff the
  /// re-subscribe status against [_ScripthashState.statusAtFetch] and skip
  /// the history/listunspent refetch for every unchanged scripthash.
  String get _scripthashStatePrefKey => prefKey('cachedScripthashState');

  @override
  Future<void> persistWalletSnapshot() async {
    await super.persistWalletSnapshot();
    await _persistTxCache();
    await _persistScripthashState();
  }

  @override
  Future<void> loadPersistedSnapshot() async {
    await super.loadPersistedSnapshot();
    await _loadTxCache();
    await _loadScripthashState();
  }

  @override
  Future<void> clearPersistedState() async {
    await super.clearPersistedState();
    await SharedPreferencesService.remove(_txCachePrefKey);
    await SharedPreferencesService.remove(_scripthashStatePrefKey);
  }

  Future<void> _persistTxCache() async {
    if (_disableCache) return;
    if (_txCache.isEmpty) return;
    try {
      final json = jsonEncode({
        'entries': [
          for (final e in _txCache.entries)
            {
              'txid': e.key,
              'verbose': e.value.verbose,
              'height': e.value.height,
              'first_seen_at': e.value.firstSeenAt,
              if (e.value.broadcastAt != null) 'broadcast_at': e.value.broadcastAt,
            },
        ],
      });
      await SharedPreferencesService.set<String>(_txCachePrefKey, json);
    } catch (e) {
      walletLog(LogLevel.warn, 'persist tx cache: $e');
    }
  }

  Future<void> _loadTxCache() async {
    if (_disableCache) return;
    try {
      final raw = await SharedPreferencesService.get<String>(_txCachePrefKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final entries = decoded['entries'];
      if (entries is! List) return;
      var loaded = 0;
      for (final entry in entries) {
        if (entry is! Map) continue;
        final txid = entry['txid'] as String?;
        final verbose = entry['verbose'];
        final height = (entry['height'] as num?)?.toInt();
        final firstSeenAt = (entry['first_seen_at'] as num?)?.toInt();
        final broadcastAt = (entry['broadcast_at'] as num?)?.toInt();
        if (txid == null || verbose is! Map || height == null || firstSeenAt == null) {
          continue;
        }
        _txCache[txid] = _TxCacheEntry(
          verbose: Map<String, dynamic>.from(verbose),
          height: height,
          firstSeenAt: firstSeenAt,
          broadcastAt: broadcastAt,
        );
        loaded++;
      }
      if (loaded > 0) {
        walletLog(LogLevel.info, 'tx cache loaded: $loaded entries');
      }
    } catch (e) {
      walletLog(LogLevel.warn, 'load tx cache: $e');
    }
  }

  Future<void> _persistScripthashState() async {
    if (_disableCache) return;
    if (_scripthashState.isEmpty) return;
    try {
      final json = jsonEncode({
        'entries': [
          for (final e in _scripthashState.entries)
            {
              'sh': e.key,
              'confirmed': e.value.confirmed,
              'unconfirmed': e.value.unconfirmed,
              'history': e.value.history,
              'unspent': e.value.unspent,
              if (e.value.statusAtFetch != null) 'status': e.value.statusAtFetch,
            },
        ],
      });
      await SharedPreferencesService.set<String>(_scripthashStatePrefKey, json);
    } catch (e) {
      walletLog(LogLevel.warn, 'persist scripthash state: $e');
    }
  }

  Future<void> _loadScripthashState() async {
    if (_disableCache) return;
    try {
      final raw = await SharedPreferencesService.get<String>(_scripthashStatePrefKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final entries = decoded['entries'];
      if (entries is! List) return;
      var loaded = 0;
      for (final entry in entries) {
        if (entry is! Map) continue;
        final sh = entry['sh'] as String?;
        if (sh == null) continue;
        final status = entry['status'] as String?;
        _scripthashState[sh] = _ScripthashState(
          confirmed: (entry['confirmed'] as num?)?.toInt() ?? 0,
          unconfirmed: (entry['unconfirmed'] as num?)?.toInt() ?? 0,
          history: _castList(entry['history']),
          unspent: _castList(entry['unspent']),
          statusAtFetch: status,
        );
        // Seed the diff baseline so a re-subscribe that returns the same
        // status hash skips the history/listunspent refetch in [refresh].
        _statusByScripthash[sh] = status;
        loaded++;
      }
      if (loaded > 0) {
        walletLog(LogLevel.info, 'scripthash state loaded: $loaded entries');
      }
    } catch (e) {
      walletLog(LogLevel.warn, 'load scripthash state: $e');
    }
  }

  @override
  Future<void> deleteFiles() async {
    try {
      await _client.close();
    } catch (_) {}
    final file = await _walletFile();
    if (await file.exists()) await file.delete();
    _mnemonic = null;
    _clearHdCache();
    _lastPassword = null;
    _addresses.clear();
    _scripthashState.clear();
    _subscribedScripthashes.clear();
    _statusByScripthash.clear();
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _pushPending = false;
    _txCache.clear();
    _bestHeight = 0;
  }

  // ----- HD derivation -----

  Bip32Slip10Secp256k1 _deriveAccountHd(String mnemonic) {
    final seedBytes = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
    return Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath(_bip84AccountPath)
        as Bip32Slip10Secp256k1;
  }

  /// Memoised per-chain HD node. The first call derives `account / chain`,
  /// every subsequent address on the same chain reuses it — turning the
  /// per-address cost from "chain + index" down to "index only".
  Bip32Slip10Secp256k1 _chainHd(int chain) {
    final cached = chain == _internalChain ? _internalHd : _externalHd;
    if (cached != null) return cached;
    final timer = Stopwatch()..start();
    final derived = _requireAccountHd().childKey(Bip32KeyIndex(chain));
    timer.stop();
    walletLog(
      LogLevel.info,
      'chainHd[${chain == _internalChain ? 'internal' : 'external'}] '
      'derive in ${timer.elapsedMilliseconds}ms',
    );
    if (chain == _internalChain) {
      return _internalHd = derived;
    }
    return _externalHd = derived;
  }

  /// Re-derives an HD address record at [index] on [chain]. Cheap; no I/O.
  _BtcAddress _generateAddress(int chain, int index) {
    final hd = _chainHd(chain).childKey(Bip32KeyIndex(index));
    final pub = ECPublic.fromBip32(hd.publicKey);
    final p2wpkh = pub.toP2wpkhAddress();
    final addressStr = p2wpkh.toAddress(_network);
    final scriptHash = BitcoinAddressUtils.scriptHash(addressStr, network: _network);
    return _BtcAddress(
      index: index,
      isChange: chain == _internalChain,
      address: addressStr,
      scriptHash: scriptHash,
    );
  }

  /// Ensures we have generated `count` addresses on the given [chain].
  /// Idempotent and cheap.
  void _ensureAddressesUpTo(int chain, int count) {
    if (_mnemonic == null) return;
    final existing = _addresses
        .where((a) => a.isChange == (chain == _internalChain))
        .map((a) => a.index)
        .toSet();
    final missing = <int>[
      for (var i = 0; i < count; i++)
        if (!existing.contains(i)) i,
    ];
    if (missing.isEmpty) return;
    final timer = Stopwatch()..start();
    for (final i in missing) {
      _addresses.add(_generateAddress(chain, i));
    }
    timer.stop();
    walletLog(
      LogLevel.info,
      'ensureAddressesUpTo[${chain == _internalChain ? 'internal' : 'external'}] '
      'in ${timer.elapsedMilliseconds}ms (${missing.length} new addrs)',
    );
  }

  // ----- Connection / refresh -----

  @override
  bool get canConnectBeforeOpen => true;

  @override
  Future<void> connectToDaemonImpl({
    required String address,
    String? proxyPort,
    required bool useSsl,
  }) async {
    // Idempotent: pre-open connect + post-open connect share the same socket.
    if (_client.isConnected) {
      walletLog(LogLevel.info, 'connectToDaemonImpl skipped (already connected)');
      return;
    }

    final parts = address.split(':');
    if (parts.length != 2) {
      throw FormatException('Electrum address must be host:port (got "$address")');
    }
    final host = parts[0];
    final port = int.tryParse(parts[1]);
    if (port == null) {
      throw FormatException('Electrum port must be numeric (got "${parts[1]}")');
    }

    final socksPort = (proxyPort != null && proxyPort.isNotEmpty) ? int.tryParse(proxyPort) : null;

    walletLog(LogLevel.info, 'Connecting to $host:$port (ssl=$useSsl, socks=$socksPort)');
    final total = Stopwatch()..start();

    final socketTimer = Stopwatch()..start();
    await _client.connect(host: host, port: port, useSsl: useSsl, socksPort: socksPort);
    socketTimer.stop();

    // Push routes get registered before any subscribe RPC so notifications
    // that race the initial response aren't dropped.
    _client.setScripthashStatusHandler(_onScripthashStatusPush);

    // server.version (result only logged) and headers.subscribe are
    // independent — fire concurrently to save a round-trip.
    final versionTimer = Stopwatch()..start();
    final versionFuture = () async {
      try {
        await _client.serverVersion();
      } catch (e) {
        walletLog(LogLevel.warn, 'server.version failed: $e');
      }
    }().whenComplete(versionTimer.stop);

    final headerTimer = Stopwatch()..start();
    final headerFuture = () async {
      try {
        final initialHeader = await _client.subscribeHeaders((header) {
          _cacheBlockTimeFromHeader(header);
          final h = (header['height'] as num?)?.toInt();
          if (h != null && h >= _bestHeight) {
            _bestHeight = h;
          }
        });
        _cacheBlockTimeFromHeader(initialHeader);
        final h = (initialHeader['height'] as num?)?.toInt();
        if (h != null) _bestHeight = h;
      } catch (e) {
        walletLog(LogLevel.warn, 'header subscribe failed: $e');
      }
    }().whenComplete(headerTimer.stop);

    await Future.wait([versionFuture, headerFuture]);

    total.stop();
    walletLog(
      LogLevel.info,
      'connectToDaemonImpl in ${total.elapsedMilliseconds}ms '
      '(socket ${socketTimer.elapsedMilliseconds}ms, '
      'server.version ${versionTimer.elapsedMilliseconds}ms, '
      'headers.subscribe ${headerTimer.elapsedMilliseconds}ms)',
    );
  }

  @override
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
    String connectionType = '',
  }) async {
    final parts = address.split(':');
    if (parts.length != 2) {
      throw FormatException('Electrum address must be host:port (got "$address")');
    }
    final host = parts[0];
    final port = int.tryParse(parts[1]);
    if (port == null) {
      throw FormatException('Electrum port must be numeric (got "${parts[1]}")');
    }
    final socksPort = (proxyPort != null && proxyPort.isNotEmpty) ? int.tryParse(proxyPort) : null;

    walletLog(LogLevel.info, 'Probing $host:$port (ssl=$useSsl, socks=$socksPort)');
    await probeElectrumServer(host: host, port: port, useSsl: useSsl, socksPort: socksPort);
  }

  @override
  Future<bool> getIsConnected() async => _client.isConnected;

  @override
  Future<void> refresh() async {
    if (_mnemonic == null || !_client.isConnected) return;
    if (_refreshing) return;
    _refreshing = true;
    final totalTimer = Stopwatch()..start();
    var newSubs = 0;
    var walkMs = 0;
    try {
      // Chains hold disjoint scripthashes, so walk them concurrently.
      final walks = await Future.wait([_walkChain(_externalChain), _walkChain(_internalChain)]);
      _nextReceiveIndex = walks[0].nextUnused;
      _nextChangeIndex = walks[1].nextUnused;
      newSubs = walks[0].newSubs + walks[1].newSubs;
      final toFetch = <String>{...walks[0].toFetch, ...walks[1].toFetch};

      walkMs = totalTimer.elapsedMilliseconds;

      var fetchMs = 0;
      if (toFetch.isNotEmpty) {
        final fetchTimer = Stopwatch()..start();
        await _fetchScripthashStates(toFetch);
        fetchTimer.stop();
        fetchMs = fetchTimer.elapsedMilliseconds;
      }

      totalTimer.stop();
      walletLog(
        LogLevel.info,
        'refresh in ${totalTimer.elapsedMilliseconds}ms '
        '(walk ${walkMs}ms, fetch ${fetchMs}ms, '
        '$newSubs new subs, ${toFetch.length} fetched)',
      );
    } catch (e) {
      if (isElectrumDisconnectError(e)) {
        walletLog(LogLevel.warn, 'refresh aborted: connection lost');
        return;
      }
      rethrow;
    } finally {
      _refreshing = false;
    }
  }

  /// Walks one chain in `_gapLimit` windows, batch-subscribing unsubscribed
  /// scripthashes per window. Returns the next unused index, the stale
  /// scripthashes to refetch, and the count of new subscriptions. Status
  /// hash == null means "no history" → contributes to the gap.
  Future<({int nextUnused, Set<String> toFetch, int newSubs})> _walkChain(int chain) async {
    final toFetch = <String>{};
    var newSubs = 0;
    var lastUsed = -1;
    var batchStart = 0;
    while (_client.isConnected) {
      final batchEnd = batchStart + _gapLimit;
      _ensureAddressesUpTo(chain, batchEnd);

      final reqs = <BatchRpc>[];
      final reqShs = <String>[];
      for (var i = batchStart; i < batchEnd; i++) {
        final sh = _addressFor(chain, i).scriptHash;
        if (!_subscribedScripthashes.contains(sh)) {
          reqs.add(BatchRpc('blockchain.scripthash.subscribe', [sh]));
          reqShs.add(sh);
        }
      }
      if (reqs.isNotEmpty) {
        final results = await _client.callBatch(reqs);
        for (var i = 0; i < results.length; i++) {
          final sh = reqShs[i];
          _subscribedScripthashes.add(sh);
          _statusByScripthash[sh] = results[i] is String ? results[i] as String : null;
          newSubs++;
        }
      }

      for (var i = batchStart; i < batchEnd; i++) {
        final sh = _addressFor(chain, i).scriptHash;
        final status = _statusByScripthash[sh];
        if (status != null) {
          if (i > lastUsed) lastUsed = i;
          final cached = _scripthashState[sh];
          if (cached == null || cached.statusAtFetch != status) {
            toFetch.add(sh);
          }
        } else {
          _scripthashState.remove(sh);
        }
      }

      if (batchEnd - 1 - lastUsed >= _gapLimit) break;
      batchStart = batchEnd;
    }
    return (nextUnused: lastUsed + 1, toFetch: toFetch, newSubs: newSubs);
  }

  /// Pulls history + unspent for every stale scripthash in one batched
  /// request frame. Two RPCs per scripthash interleaved as
  /// `[h(sh0), u(sh0), h(sh1), u(sh1), …]` so we can match results back by
  /// index. Balance is summed from the unspent list, saving a third
  /// per-address round-trip vs. `blockchain.scripthash.get_balance`.
  Future<void> _fetchScripthashStates(Iterable<String> scriptHashes) async {
    final list = scriptHashes.toList(growable: false);
    if (list.isEmpty) return;

    // Snapshot statuses *before* the call so concurrent push notifications
    // that update _statusByScripthash mid-fetch don't poison statusAtFetch.
    final statusAtFetch = {for (final sh in list) sh: _statusByScripthash[sh]};

    final reqs = <BatchRpc>[
      for (final sh in list) ...[
        BatchRpc('blockchain.scripthash.get_history', [sh]),
        BatchRpc('blockchain.scripthash.listunspent', [sh]),
      ],
    ];

    final List<BatchRpcResult> results;
    try {
      results = await _client.callBatchTolerant(reqs);
    } catch (e) {
      if (isElectrumDisconnectError(e)) rethrow;
      walletLog(LogLevel.warn, 'fetch scripthash batch failed: $e');
      return;
    }

    for (var i = 0; i < list.length; i++) {
      final sh = list[i];
      final hResult = results[i * 2];
      final uResult = results[i * 2 + 1];
      if (hResult.error != null || uResult.error != null) {
        final err = hResult.error ?? uResult.error!;
        if (isElectrumDisconnectError(err)) throw err;
        walletLog(LogLevel.warn, 'fetch scripthash $sh: $err');
        continue;
      }

      final history = _castList(hResult.result);
      final unspent = _castList(uResult.result);

      var confirmed = 0;
      var unconfirmed = 0;
      for (final u in unspent) {
        final value = (u['value'] as num?)?.toInt() ?? 0;
        final h = (u['height'] as num?)?.toInt() ?? 0;
        if (h > 0) {
          confirmed += value;
        } else {
          unconfirmed += value;
        }
      }

      _scripthashState[sh] = _ScripthashState(
        confirmed: confirmed,
        unconfirmed: unconfirmed,
        history: history,
        unspent: unspent,
        statusAtFetch: statusAtFetch[sh],
      );
    }
  }

  static List<Map<String, dynamic>> _castList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// Handler for `blockchain.scripthash.subscribe` push notifications. Just
  /// records the new status and schedules a debounced refresh. The walk in
  /// [refresh] uses the cached status to decide what to refetch.
  void _onScripthashStatusPush(String sh, String? status) {
    final prev = _statusByScripthash[sh];
    if (prev == status) return;
    _statusByScripthash[sh] = status;
    if (status == null) {
      _scripthashState.remove(sh);
    }
    _pushPending = true;
    if (_pushHandlerActive) return; // current run will loop and pick it up
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 250), () {
      _pushDebounce = null;
      unawaited(_runPushRefresh());
    });
  }

  Future<void> _runPushRefresh() async {
    if (_pushHandlerActive) return;
    _pushHandlerActive = true;
    try {
      // Loop so notifications that arrive during a refresh still get picked
      // up. _pushPending is set by the push handler on every state change.
      while (_pushPending && _client.isConnected) {
        _pushPending = false;
        try {
          await refresh();
          await loadAllStats();
        } catch (e) {
          if (isElectrumDisconnectError(e)) {
            walletLog(LogLevel.warn, 'push refresh aborted: connection lost');
            return;
          }
          walletLog(LogLevel.warn, 'push refresh failed: $e');
        }
      }
    } finally {
      _pushHandlerActive = false;
    }
  }

  _BtcAddress _addressFor(int chain, int index) {
    return _addresses.firstWhere(
      (a) => a.index == index && a.isChange == (chain == _internalChain),
    );
  }

  // ----- Stats -----

  int _sumBalanceSats() {
    var sats = 0;
    for (final s in _scripthashState.values) {
      sats += s.confirmed + s.unconfirmed;
    }
    return sats;
  }

  @override
  bool get canSpendPendingBalance => true;

  @override
  Future<void> loadIsSynced() async {
    setIsSynced(_client.isConnected && _bestHeight > 0);
  }

  @override
  Future<void> loadSyncedHeight() async {
    setSyncedHeight(_bestHeight > 0 ? _bestHeight : null);
  }

  @override
  Future<void> loadTotalBalance() async {
    if (!_client.isConnected) return;
    setTotalBalance(_sumBalanceSats() / _satsPerBtc);
  }

  @override
  Future<void> loadUnlockedBalance() async {
    if (!_client.isConnected) return;
    setUnlockedBalance(_sumBalanceSats() / _satsPerBtc);
  }

  @override
  Future<int> getCurrentHeight() async => _bestHeight;

  @override
  Future<int> getRestoreHeight() async {
    return await SharedPreferencesService.get<int>(prefKey('walletRestoreHeight')) ?? 0;
  }

  // ----- Tx history -----

  @override
  List<TxDetails> readTxHistory() {
    final ourAddresses = _addresses.map((a) => a.address).toSet();
    final ourChangeAddresses = _addresses.where((a) => a.isChange).map((a) => a.address).toSet();
    final entries = <TxDetails>[];

    for (final entry in _txCache.values) {
      final tx = entry.verbose;
      final hash = tx['hash'] as String? ?? tx['txid'] as String? ?? '';
      if (hash.isEmpty) continue;

      final vouts = (tx['vout'] as List?) ?? [];
      final vins = (tx['vin'] as List?) ?? [];

      var inputsFromUs = 0;
      var inputsFromUsValueSats = 0;
      var inputsTotalSats = 0;
      for (final vin in vins) {
        if (vin is! Map) continue;
        final prev = vin['prevout'];
        if (prev is Map) {
          final v = (prev['value'] as num?)?.toDouble();
          if (v != null) {
            inputsTotalSats += _btcToSats(v);
          }
          final prevAddr = _addressFromScriptPubKey(prev);
          if (prevAddr != null && ourAddresses.contains(prevAddr)) {
            inputsFromUs++;
            if (v != null) inputsFromUsValueSats += _btcToSats(v);
          }
        }
      }
      final isOutgoing = inputsFromUs > 0;

      var outputsToUsSats = 0;
      var outputsToOthersSats = 0;
      var outputsTotalSats = 0;
      final recipients = <TxRecipient>[];
      for (final vout in vouts) {
        if (vout is! Map) continue;
        final scriptPubKey = vout['scriptPubKey'];
        final addr = scriptPubKey is Map ? _addressFromScriptPubKey(scriptPubKey) : null;
        final valueBtc = (vout['value'] as num?)?.toDouble() ?? 0;
        final valueSats = _btcToSats(valueBtc);
        outputsTotalSats += valueSats;
        if (addr != null && ourAddresses.contains(addr)) {
          outputsToUsSats += valueSats;
          if (!isOutgoing) {
            recipients.add(TxRecipient(addr, valueBtc));
          } else {
            recipients.add(TxRecipient(addr, valueBtc, isChange: ourChangeAddresses.contains(addr)));
          }
        } else {
          outputsToOthersSats += valueSats;
          if (isOutgoing && addr != null) {
            recipients.add(TxRecipient(addr, valueBtc));
          }
        }
      }

      final amountSats = isOutgoing ? outputsToOthersSats : outputsToUsSats;
      var feeSats = 0;
      if (isOutgoing && inputsFromUs == vins.length) {
        final outSum = outputsToUsSats + outputsToOthersSats;
        if (inputsFromUsValueSats > outSum) {
          feeSats = inputsFromUsValueSats - outSum;
        }
      } else if (!isOutgoing && inputsTotalSats > outputsTotalSats) {
        final allInputsKnown =
            vins.isNotEmpty &&
            vins.every((vin) => vin is Map && (vin.isEmpty || vin['prevout'] is Map));
        if (allInputsKnown) {
          feeSats = inputsTotalSats - outputsTotalSats;
        }
      }

      final blockHeight = _txBlockHeight(tx, entry.height);
      final chainTip = _chainTipForConfirmations;
      final confirmations = blockHeight > 0 && chainTip >= blockHeight
          ? chainTip - blockHeight + 1
          : 0;
      final timestamp = _displayTxTimestamp(tx, entry);

      entries.add(
        TxDetails(
          index: null,
          direction: isOutgoing ? consts.txDirectionOutgoing : consts.txDirectionIncoming,
          hash: hash,
          amount: amountSats / _satsPerBtc,
          fee: feeSats / _satsPerBtc,
          recipients: recipients,
          accountIndex: 0,
          subaddrIndexList: [],
          timestamp: timestamp,
          height: blockHeight,
          confirmations: confirmations,
          key: '',
          broadcastAt: entry.broadcastAt,
        ),
      );
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  @override
  Future<void> loadTxHistory({bool persistCount = true}) async {
    if (!_client.isConnected) return;

    final total = Stopwatch()..start();
    final priorCacheSize = _txCache.length;
    var fetchedCount = 0;
    var verboseMs = 0;
    var rawMs = 0;
    var hydrateMs = 0;
    var headersMs = 0;

    final priorBroadcastAt = {
      for (final tx in txHistory)
        if (tx.broadcastAt != null && tx.broadcastAt! > 0) tx.hash: tx.broadcastAt!,
    };

    // Phase 1 — discover + cache fast-path.
    final discoverTimer = Stopwatch()..start();
    final newHashes = <String, int>{}; // txHash -> height
    for (final state in _scripthashState.values) {
      for (final entry in state.history) {
        final txHash = entry['tx_hash'] as String?;
        if (txHash == null) continue;
        final height = (entry['height'] as num?)?.toInt() ?? 0;
        newHashes[txHash] = height;
      }
    }

    final toFetch = <String>[];
    for (final entry in newHashes.entries) {
      final txid = entry.key;
      final height = entry.value;
      final cached = _txCache[txid];
      if (cached == null) {
        toFetch.add(txid);
        continue;
      }
      // A cached entry without outputs is a placeholder (e.g. a just-broadcast
      // tx) and must be replaced with the real fetched tx data.
      final incomplete = (cached.verbose['vout'] as List?)?.isNotEmpty != true;
      // Monotonic height: don't downgrade a known confirmation back to mempool
      // (0) on a transient/stale history read.
      final effectiveHeight = height > 0 ? height : cached.height;
      if (cached.height != effectiveHeight || incomplete) {
        _txCache[txid] = _TxCacheEntry(
          verbose: cached.verbose,
          height: effectiveHeight,
          firstSeenAt: cached.firstSeenAt,
          broadcastAt: _resolveBroadcastAt(
            txHash: txid,
            historyHeight: effectiveHeight,
            cached: cached,
            priorBroadcastAt: priorBroadcastAt,
          ),
        );
        if (effectiveHeight <= 0 || incomplete) toFetch.add(txid);
      }
    }
    discoverTimer.stop();

    // Phase 2 — verbose + raw + hydrate.
    if (toFetch.isNotEmpty) {
      try {
        final verboseByTxid = <String, Map<String, dynamic>>{};
        final rawHexByTxid = <String, String>{};

        final verboseTimer = Stopwatch()..start();
        final needRaw = _serverSupportsVerboseTx
            ? await _batchVerboseGets(toFetch, verboseByTxid, rawHexByTxid)
            : List<String>.from(toFetch);
        verboseTimer.stop();
        verboseMs = verboseTimer.elapsedMilliseconds;

        if (needRaw.isNotEmpty) {
          final rawTimer = Stopwatch()..start();
          await _batchRawGets(needRaw, rawHexByTxid);
          rawTimer.stop();
          rawMs = rawTimer.elapsedMilliseconds;
        }

        // Pre-fetch every missing parent in one frame so the per-tx hydrate
        // step finds them locally instead of paying a round-trip each.
        await _prefetchAllParents(rawHexByTxid);

        // Snapshot key set: _ensureParentRaws may still grow the map.
        final rawsToHydrate = [
          for (final txid in rawHexByTxid.keys)
            if (!verboseByTxid.containsKey(txid)) txid,
        ];
        final hydrateTimer = Stopwatch()..start();
        for (final txid in rawsToHydrate) {
          try {
            final h = newHashes[txid] ?? 0;
            verboseByTxid[txid] = await _verboseMapFromRaw(
              rawHexByTxid[txid]!,
              txid,
              rawHexByTxid,
              blockHeight: h > 0 ? h : (_txCache[txid]?.height ?? 0),
            );
          } catch (e) {
            if (isElectrumDisconnectError(e)) rethrow;
            walletLog(LogLevel.warn, 'verbose-from-raw $txid: $e');
          }
        }
        hydrateTimer.stop();
        hydrateMs = hydrateTimer.elapsedMilliseconds;

        fetchedCount = toFetch.length;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final txid in toFetch) {
          final verbose = verboseByTxid[txid];
          if (verbose == null) continue;
          final cached = _txCache[txid];
          final rawHeight = newHashes[txid] ?? 0;
          final height = rawHeight > 0 ? rawHeight : (cached?.height ?? 0);
          _txCache[txid] = _TxCacheEntry(
            verbose: verbose,
            height: height,
            firstSeenAt: cached?.firstSeenAt ?? now,
            broadcastAt: _resolveBroadcastAt(
              txHash: txid,
              historyHeight: height,
              cached: cached,
              priorBroadcastAt: priorBroadcastAt,
              now: now,
            ),
          );
        }
      } catch (e) {
        if (isElectrumDisconnectError(e)) {
          walletLog(LogLevel.warn, 'loadTxHistory aborted: connection lost');
        } else {
          walletLog(LogLevel.warn, 'loadTxHistory batch fetch failed: $e');
        }
      }
    }

    // Phase 3 — block headers for verbose-less timestamps.
    final headersTimer = Stopwatch()..start();
    try {
      final heightsNeedingTime = <int>{};
      for (final entry in _txCache.values) {
        final tx = entry.verbose;
        final fromVerbose = (tx['blocktime'] as num?)?.toInt() ?? (tx['time'] as num?)?.toInt();
        if (fromVerbose != null && fromVerbose > 0) continue;
        final h = _txBlockHeight(tx, entry.height);
        if (h > 0) heightsNeedingTime.add(h);
      }
      await _ensureBlockTimestamps(heightsNeedingTime);
    } catch (e) {
      if (isElectrumDisconnectError(e)) {
        walletLog(LogLevel.warn, 'loadTxHistory block times aborted: connection lost');
      } else {
        walletLog(LogLevel.warn, 'loadTxHistory block times failed: $e');
      }
    }
    headersTimer.stop();
    headersMs = headersTimer.elapsedMilliseconds;

    // Phase 4 — base class render (txHistory build + persist).
    final renderTimer = Stopwatch()..start();
    await super.loadTxHistory(persistCount: persistCount);
    renderTimer.stop();

    total.stop();
    walletLog(
      LogLevel.info,
      'loadTxHistory in ${total.elapsedMilliseconds}ms '
      '(discover ${discoverTimer.elapsedMilliseconds}ms, '
      'verbose ${verboseMs}ms, raw ${rawMs}ms, hydrate ${hydrateMs}ms, '
      'headers ${headersMs}ms, render ${renderTimer.elapsedMilliseconds}ms, '
      '$fetchedCount fetched, ${_txCache.length - priorCacheSize} new in cache)',
    );
  }

  /// Batched verbose=true fetch. Map results populate [verboseInto]; bare
  /// hex-string results populate [rawInto]; per-entry errors that look
  /// like "verbose unsupported" are accumulated and returned for the
  /// caller to retry with `verbose=false`.
  Future<List<String>> _batchVerboseGets(
    List<String> txids,
    Map<String, Map<String, dynamic>> verboseInto,
    Map<String, String> rawInto,
  ) async {
    final reqs = [
      for (final t in txids) BatchRpc('blockchain.transaction.get', [t, true]),
    ];
    final results = await _client.callBatchTolerant(reqs);
    final needRaw = <String>[];
    for (var i = 0; i < txids.length; i++) {
      final txid = txids[i];
      final r = results[i];
      if (r.error != null) {
        if (isElectrumDisconnectError(r.error!)) throw r.error!;
        if (_isVerboseUnsupportedError(r.error!)) {
          needRaw.add(txid);
        } else {
          walletLog(LogLevel.warn, 'getTransaction $txid: ${r.error}');
        }
        continue;
      }
      final result = r.result;
      if (result is Map) {
        verboseInto[txid] = Map<String, dynamic>.from(result);
      } else if (result is String) {
        rawInto[txid] = result;
      }
    }
    // Demote to raw-only mode if no verbose result came back and at least
    // one entry failed with a verbose-unsupported error. From now on
    // [loadTxHistory] skips the verbose round-trip for this wallet.
    if (_serverSupportsVerboseTx && verboseInto.isEmpty && needRaw.length == txids.length) {
      _serverSupportsVerboseTx = false;
      walletLog(
        LogLevel.info,
        'server rejects verbose transactions; switching to raw-only fetch path',
      );
    }
    return needRaw;
  }

  /// Batched verbose=false fetch, used as a fallback when the server
  /// rejects verbose. Successful hex strings land in [rawInto].
  Future<void> _batchRawGets(List<String> txids, Map<String, String> rawInto) async {
    final reqs = [
      for (final t in txids) BatchRpc('blockchain.transaction.get', [t, false]),
    ];
    final results = await _client.callBatchTolerant(reqs);
    for (var i = 0; i < txids.length; i++) {
      final txid = txids[i];
      final r = results[i];
      if (r.error != null) {
        if (isElectrumDisconnectError(r.error!)) throw r.error!;
        walletLog(LogLevel.warn, 'getTransaction raw $txid: ${r.error}');
        continue;
      }
      if (r.result is String) rawInto[txid] = r.result as String;
    }
  }

  static bool _isVerboseUnsupportedError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('verbose') || msg.contains('not supported') || msg.contains('unsupported');
  }

  // ----- Send / receive -----

  @override
  String getPrimaryAddress() {
    _ensureAddressesUpTo(_externalChain, 1);
    return _addressFor(_externalChain, 0).address;
  }

  @override
  String? getReceiveAddress() {
    _ensureAddressesUpTo(_externalChain, _nextReceiveIndex + 1);
    return _addressFor(_externalChain, _nextReceiveIndex).address;
  }

  @override
  bool isAddressValid(String address) {
    try {
      // Throws if the address can't be decoded under the configured network.
      P2wpkhAddress.fromAddress(address: address, network: _network);
      return true;
    } catch (_) {}
    try {
      P2pkhAddress.fromAddress(address: address, network: _network);
      return true;
    } catch (_) {}
    try {
      P2shAddress.fromAddress(address: address, network: _network);
      return true;
    } catch (_) {}
    try {
      P2trAddress.fromAddress(address: address, network: _network);
      return true;
    } catch (_) {}
    return false;
  }

  @override
  Future<PendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority = 0,
  }) async {
    _requireAccountHd();

    final feeRateSatVb = await _resolveFeeRateSatVb(priority);
    final allUtxos = _collectSpendableUtxos();
    if (allUtxos.isEmpty) {
      throw Exception('No spendable outputs available.');
    }

    final amountSats = (amount * _satsPerBtc).round();
    final destAddress = _decodeDestinationAddress(destinationAddress);

    final List<_SpendableUtxo> selection;
    final bool useChange;
    if (isSweepAll) {
      selection = _selectAllUtxos(allUtxos);
      useChange = false;
    } else {
      final r = _selectCoins(allUtxos, amountSats, feeRateSatVb);
      selection = r.inputs;
      useChange = r.useChange;
    }

    final changeAddress = _nextChangeAddress();
    final outputs = <BitcoinOutput>[];
    int sendAmountSats;
    int feeSats;
    bool hasChange;

    final inputSum = selection.fold<int>(0, (s, u) => s + u.value);

    if (isSweepAll) {
      final estSizeNoChange = _estimateVsize(selection.length, 1);
      feeSats = (estSizeNoChange * feeRateSatVb).ceil();
      sendAmountSats = inputSum - feeSats;
      if (sendAmountSats <= 0) throw Exception('Insufficient funds for fee.');
      outputs.add(BitcoinOutput(address: destAddress, value: BigInt.from(sendAmountSats)));
      hasChange = false;
    } else {
      sendAmountSats = amountSats;
      outputs.add(BitcoinOutput(address: destAddress, value: BigInt.from(sendAmountSats)));

      // Pre-compute change against a 2-output tx. Branch-and-bound returns a
      // changeless set (useChange == false); for the fallback, drop change if
      // it'd be dust.
      final estSizeWithChange = _estimateVsize(selection.length, 2);
      final changeSats = inputSum - sendAmountSats - (estSizeWithChange * feeRateSatVb).ceil();
      hasChange = useChange && changeSats > _dustThresholdSats;

      if (hasChange) {
        feeSats = inputSum - sendAmountSats - changeSats;
        outputs.add(
          BitcoinOutput(
            address: P2wpkhAddress.fromAddress(address: changeAddress, network: _network),
            value: BigInt.from(changeSats),
          ),
        );
      } else {
        // No change: the remainder becomes fee. Guard it covers a 1-output tx.
        feeSats = inputSum - sendAmountSats;
        if (feeSats < 0 || feeSats < (_estimateVsize(selection.length, 1) * feeRateSatVb).ceil()) {
          throw Exception('Insufficient funds for fee.');
        }
      }
    }

    final builderUtxos = selection.map((u) => u.toUtxoWithAddress(_network)).toList();
    // RBF uses nSequence 0x00000001 (1-block relative locktime). That is
    // non-BIP68-final when spending unconfirmed parent outputs.
    final spendsUnconfirmed = selection.any((u) => !u.isConfirmed);
    final txb = BitcoinTransactionBuilder(
      utxos: builderUtxos,
      outputs: outputs,
      fee: BigInt.from(feeSats),
      network: _network,
      outputOrdering: BitcoinOrdering.none,
      enableRBF: !spendsUnconfirmed,
    );

    final transaction = txb.buildTransaction((txDigest, utxo, publicKey, sigHash) {
      final spend = selection.firstWhere(
        (u) => u.publicKeyHex == publicKey,
        orElse: () => throw StateError('No private key for input ${utxo.utxo.txHash}'),
      );
      return spend.privateKey.signInput(txDigest, sigHash: sigHash);
    });

    return BitcoinPendingTx(
      amount: sendAmountSats / _satsPerBtc,
      fee: feeSats / _satsPerBtc,
      rawHex: transaction.toHex(),
      spentOutpoints: selection
          .map((u) => (txHash: u.txHash, vout: u.vout))
          .toList(growable: false),
    );
  }

  @override
  Future<void> commitTx(PendingTransaction tx, String destinationAddress) async {
    if (tx is! BitcoinPendingTx) {
      throw ArgumentError('BitcoinChainWallet.commitTx requires a BitcoinPendingTx');
    }
    final txid = await _client.broadcastTransaction(tx.rawHex);
    walletLog(LogLevel.info, 'broadcast ok: $txid');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cached = _txCache[txid];
    _txCache[txid] = _TxCacheEntry(
      verbose: cached?.verbose ?? {'hash': txid, 'txid': txid},
      height: cached?.height ?? 0,
      firstSeenAt: cached?.firstSeenAt ?? now,
      broadcastAt: now,
    );

    // Optimistically remove spent UTXOs from the cache so the next
    // refresh doesn't double-spend before the server has indexed the new tx.
    for (final state in _scripthashState.values) {
      state.unspent.removeWhere(
        (u) => tx.spentOutpoints.any(
          (o) =>
              o.txHash == (u['tx_hash'] as String? ?? '') &&
              o.vout == ((u['tx_pos'] as num?)?.toInt() ?? -1),
        ),
      );
    }

    try {
      await refresh();
      await loadTxHistory();
    } catch (e) {
      if (isElectrumDisconnectError(e)) {
        walletLog(LogLevel.warn, 'post-broadcast sync skipped: connection lost');
      } else {
        rethrow;
      }
    }
  }

  // ----- Coin selection -----

  List<_SpendableUtxo> _collectSpendableUtxos() {
    final out = <_SpendableUtxo>[];
    for (final addr in _addresses) {
      final state = _scripthashState[addr.scriptHash];
      if (state == null) continue;
      final hd = _requireAccountHd()
          .childKey(Bip32KeyIndex(addr.isChange ? _internalChain : _externalChain))
          .childKey(Bip32KeyIndex(addr.index));
      final priv = ECPrivate(hd.privateKey);
      final pub = ECPublic.fromBip32(hd.publicKey);
      for (final u in state.unspent) {
        final value = (u['value'] as num?)?.toInt() ?? 0;
        if (value <= 0) continue;
        out.add(
          _SpendableUtxo(
            txHash: u['tx_hash'] as String? ?? '',
            vout: (u['tx_pos'] as num?)?.toInt() ?? 0,
            value: value,
            height: (u['height'] as num?)?.toInt() ?? 0,
            address: addr.address,
            publicKeyHex: pub.toHex(),
            privateKey: priv,
          ),
        );
      }
    }
    return out;
  }

  /// Selects inputs for [amountSats]. Tries branch-and-bound for a changeless
  /// spend first; falls back to largest-first (which yields a change output).
  ({List<_SpendableUtxo> inputs, bool useChange}) _selectCoins(
    List<_SpendableUtxo> utxos,
    int amountSats,
    double feeRateSatVb,
  ) {
    final exact = _selectBranchAndBound(utxos, amountSats, feeRateSatVb);
    if (exact != null && exact.isNotEmpty) return (inputs: exact, useChange: false);
    return (inputs: _selectLargestFirst(utxos, amountSats, feeRateSatVb), useChange: true);
  }

  /// Branch-and-bound: a changeless input set, or null if none fits the window.
  List<_SpendableUtxo>? _selectBranchAndBound(
    List<_SpendableUtxo> utxos,
    int amountSats,
    double feeRateSatVb,
  ) {
    final inputFee = (feeRateSatVb * _inputVsize).round();
    // Effective value nets out each input's own spending fee. Drop UTXOs that
    // cost more to spend than they're worth.
    final keep = <_SpendableUtxo>[];
    final eff = <int>[];
    for (final u in utxos) {
      final ev = u.value - inputFee;
      if (ev > 0) {
        keep.add(u);
        eff.add(ev);
      }
    }
    // Input-independent fee (overhead + single recipient output).
    final fixedFee = (feeRateSatVb * (_txOverheadVsize + _outputVsize)).ceil();
    final costOfChange = (feeRateSatVb * (_outputVsize + _inputVsize)).ceil();

    final picked = branchAndBoundSelect(
      effectiveValues: eff,
      target: amountSats + fixedFee,
      costOfChange: costOfChange,
    );
    if (picked == null) return null;
    return [for (final i in picked) keep[i]];
  }

  /// Largest-first accumulation. Yields a change output; used when
  /// branch-and-bound finds no changeless match.
  List<_SpendableUtxo> _selectLargestFirst(
    List<_SpendableUtxo> utxos,
    int amountSats,
    double feeRateSatVb,
  ) {
    final sorted = [...utxos]..sort((a, b) => b.value.compareTo(a.value));
    final selected = <_SpendableUtxo>[];
    var sum = 0;
    for (final u in sorted) {
      selected.add(u);
      sum += u.value;
      final estFee = (_estimateVsize(selected.length, 2) * feeRateSatVb).ceil();
      if (sum >= amountSats + estFee) return selected;
    }
    throw Exception('Insufficient funds.');
  }

  List<_SpendableUtxo> _selectAllUtxos(List<_SpendableUtxo> utxos) =>
      List<_SpendableUtxo>.from(utxos);

  /// Conservative virtual-size estimate for a P2WPKH spend.
  int _estimateVsize(int inputs, int outputs) {
    return _txOverheadVsize + inputs * _inputVsize + outputs * _outputVsize;
  }

  Future<double> _resolveFeeRateSatVb(int priority) async {
    final blocks = switch (priority) {
      1 => 25,
      2 => 6,
      3 => 2,
      _ => 6,
    };

    // Best-effort, short timeout: fee lookups must not stall the send screen.
    const feeTimeout = Duration(seconds: 6);

    // Prefer the live mempool histogram; it's current and usually available.
    if (!_feeHistogramUnavailable) {
      try {
        final histogram = await _client.getFeeHistogram(timeout: feeTimeout);
        if (histogram.isNotEmpty) {
          final rate = feeRateForBlocks(histogram, blocks).clamp(1, 1000).toDouble();
          walletLog(
            LogLevel.info,
            'fee rate $rate sat/vB (histogram, priority $priority → $blocks blocks, '
            '${histogram.length} buckets)',
          );
          return rate;
        }
        walletLog(LogLevel.info, 'fee histogram empty; falling back to estimatefee');
      } catch (e) {
        _feeHistogramUnavailable = true;
        walletLog(LogLevel.warn, 'getFeeHistogram failed: $e');
      }
    }

    // Fall back to the node's estimator, then a static default.
    if (!_estimateFeeUnavailable) {
      try {
        final btcPerKb = await _client.estimateFee(blocks, timeout: feeTimeout);
        if (btcPerKb != null) {
          final rate = (btcPerKb * _satsPerBtc / 1000).clamp(1, 1000).toDouble();
          walletLog(
            LogLevel.info,
            'fee rate $rate sat/vB (estimatefee, priority $priority → $blocks blocks, '
            '$btcPerKb BTC/kB)',
          );
          return rate;
        }
        walletLog(LogLevel.info, 'estimatefee unavailable; using default');
      } catch (e) {
        _estimateFeeUnavailable = true;
        walletLog(LogLevel.warn, 'estimateFee($blocks) failed: $e');
      }
    }
    walletLog(
      LogLevel.info,
      'fee rate $_defaultFeeRateSatVb sat/vB (default, priority $priority → $blocks blocks)',
    );
    return _defaultFeeRateSatVb;
  }

  String _nextChangeAddress() {
    _ensureAddressesUpTo(_internalChain, _nextChangeIndex + 1);
    return _addressFor(_internalChain, _nextChangeIndex).address;
  }

  BitcoinBaseAddress _decodeDestinationAddress(String address) {
    try {
      return P2wpkhAddress.fromAddress(address: address, network: _network);
    } catch (_) {}
    try {
      return P2pkhAddress.fromAddress(address: address, network: _network);
    } catch (_) {}
    try {
      return P2shAddress.fromAddress(address: address, network: _network);
    } catch (_) {}
    try {
      return P2trAddress.fromAddress(address: address, network: _network);
    } catch (_) {}
    throw FormatException('Invalid Bitcoin address: $address');
  }

  // ----- Helpers -----

  static int _btcToSats(double btc) => (btc * _satsPerBtc).round();

  /// Best-effort extraction of an address from a verbose tx's
  /// scriptPubKey/prevout map. Different Electrum implementations return
  /// either `addresses: [..]` or a singular `address`, sometimes nested under
  /// `scriptPubKey`.
  String? _addressFromScriptPubKey(Map<dynamic, dynamic> script) {
    final direct = script['address'];
    if (direct is String) return direct;
    final list = script['addresses'];
    if (list is List && list.isNotEmpty && list.first is String) {
      return list.first as String;
    }
    final nested = script['scriptPubKey'];
    if (nested is Map) {
      return _addressFromScriptPubKey(Map<dynamic, dynamic>.from(nested));
    }
    return null;
  }

  /// Unix seconds for display, preferring mempool/broadcast time when known.
  int _displayTxTimestamp(Map<String, dynamic> tx, _TxCacheEntry entry) {
    if (entry.broadcastAt != null && entry.broadcastAt! > 0) {
      return entry.broadcastAt!;
    }
    return _txBlockTimestamp(tx, entry);
  }

  /// Unix seconds from block inclusion, verbose fields, or cached header time.
  int _txBlockTimestamp(Map<String, dynamic> tx, _TxCacheEntry entry) {
    final fromVerbose = (tx['blocktime'] as num?)?.toInt() ?? (tx['time'] as num?)?.toInt();
    if (fromVerbose != null && fromVerbose > 0) return fromVerbose;

    final blockHeight = _txBlockHeight(tx, entry.height);
    if (blockHeight > 0) {
      final blockTime = _blockTimeByHeight[blockHeight];
      if (blockTime != null && blockTime > 0) return blockTime;
    }

    return entry.firstSeenAt;
  }

  int? _resolveBroadcastAt({
    required String txHash,
    required int historyHeight,
    _TxCacheEntry? cached,
    required Map<String, int> priorBroadcastAt,
    int? now,
  }) {
    if (cached?.broadcastAt != null && cached!.broadcastAt! > 0) {
      return cached.broadcastAt;
    }
    final prior = priorBroadcastAt[txHash];
    if (prior != null && prior > 0) return prior;
    if (historyHeight == 0) return now;
    if (cached != null && cached.height == 0) return cached.firstSeenAt;
    return null;
  }

  void _cacheBlockTimeFromHeader(Map<String, dynamic> header) {
    final height = (header['height'] as num?)?.toInt();
    final hex = header['hex'] as String?;
    if (height == null || hex == null) return;
    final ts = _timestampFromBlockHeaderHex(hex);
    if (ts != null && ts > 0) _blockTimeByHeight[height] = ts;
  }

  static int? _timestampFromBlockHeaderHex(String headerHex) {
    if (headerHex.length < 144) return null;
    try {
      final bytes = Uint8List.fromList(
        List.generate(headerHex.length ~/ 2, (i) {
          return int.parse(headerHex.substring(i * 2, i * 2 + 2), radix: 16);
        }),
      );
      if (bytes.length < 72) return null;
      return bytes[68] | (bytes[69] << 8) | (bytes[70] << 16) | (bytes[71] << 24);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureBlockTimestamps(Iterable<int> heights) async {
    final missing = <int>[
      for (final h in heights)
        if (h > 0 && !_blockTimeByHeight.containsKey(h)) h,
    ];
    if (missing.isEmpty) return;

    final reqs = [
      for (final h in missing) BatchRpc('blockchain.block.header', [h]),
    ];
    final results = await _client.callBatchTolerant(reqs);
    for (var i = 0; i < missing.length; i++) {
      final h = missing[i];
      final r = results[i];
      if (r.error != null) {
        if (isElectrumDisconnectError(r.error!)) throw r.error!;
        walletLog(LogLevel.warn, 'block header $h: ${r.error}');
        continue;
      }
      if (r.result is String) {
        final ts = _timestampFromBlockHeaderHex(r.result as String);
        if (ts != null && ts > 0) _blockTimeByHeight[h] = ts;
      }
    }
  }

  /// Block height for [tx], falling back to [historyHeight] from Electrum
  /// scripthash history (`0` = unconfirmed → `-1`).
  int _txBlockHeight(Map<String, dynamic> tx, int historyHeight) {
    final fromVerbose = (tx['height'] as num?)?.toInt();
    if (fromVerbose != null && fromVerbose > 0) return fromVerbose;
    if (historyHeight > 0) return historyHeight;

    if (tx['confirmations'] is num) {
      final conf = (tx['confirmations'] as num).toInt();
      final tip = _chainTipForConfirmations;
      if (conf > 0 && tip > 0) return tip - conf + 1;
    }

    return -1;
  }

  /// Best known chain tip for confirmation math. Prefer the subscribed header
  /// height; if that is unavailable, use the highest confirmed height seen in
  /// scripthash history.
  int get _chainTipForConfirmations {
    if (_bestHeight > 0) return _bestHeight;
    var maxH = 0;
    for (final state in _scripthashState.values) {
      for (final item in state.history) {
        final h = (item['height'] as num?)?.toInt() ?? 0;
        if (h > maxH) maxH = h;
      }
    }
    return maxH;
  }

  static bool _isNullPreviousOutpoint(String txIdHex) {
    if (txIdHex.length != 64) return false;
    for (var k = 0; k < txIdHex.length; k++) {
      if (txIdHex.toLowerCase().codeUnitAt(k) != 0x30) return false;
    }
    return true;
  }

  /// Pulls every missing parent referenced by [tx]'s inputs in one frame.
  Future<void> _ensureParentRaws(BtcTransaction tx, Map<String, String> rawHexByTxid) async {
    final missing = <String>{};
    for (final i in tx.inputs) {
      if (_isNullPreviousOutpoint(i.txId)) continue;
      if (!rawHexByTxid.containsKey(i.txId)) missing.add(i.txId);
    }
    await _fetchParentRawsByTxid(missing, rawHexByTxid);
  }

  /// Walks every raw already in [rawHexByTxid], collects all unique parent
  /// txids that aren't yet present, and fetches them in one batched frame.
  Future<void> _prefetchAllParents(Map<String, String> rawHexByTxid) async {
    final missing = <String>{};
    final knownTxids = rawHexByTxid.keys.toSet();
    for (final hex in rawHexByTxid.values.toList(growable: false)) {
      final tx = BtcTransaction.fromRaw(hex);
      for (final i in tx.inputs) {
        if (_isNullPreviousOutpoint(i.txId)) continue;
        if (!knownTxids.contains(i.txId)) missing.add(i.txId);
      }
    }
    await _fetchParentRawsByTxid(missing, rawHexByTxid);
  }

  Future<void> _fetchParentRawsByTxid(Set<String> missing, Map<String, String> rawHexByTxid) async {
    if (missing.isEmpty) return;
    final txids = missing.toList(growable: false);
    final reqs = [
      for (final t in txids) BatchRpc('blockchain.transaction.get', [t, false]),
    ];
    final results = await _client.callBatchTolerant(reqs);
    for (var i = 0; i < txids.length; i++) {
      final txid = txids[i];
      final r = results[i];
      if (r.error != null) {
        if (isElectrumDisconnectError(r.error!)) throw r.error!;
        walletLog(LogLevel.warn, 'getTransaction raw parent $txid: ${r.error}');
        continue;
      }
      if (r.result is String) rawHexByTxid[txid] = r.result as String;
    }
  }

  /// When Electrum returns only raw hex (no verbose JSON), build a
  /// structure compatible with [readTxHistory], including prevouts from
  /// parent raw transactions.
  Future<Map<String, dynamic>> _verboseMapFromRaw(
    String rawHex,
    String txHash,
    Map<String, String> rawHexByTxid, {
    int blockHeight = 0,
  }) async {
    final tx = BtcTransaction.fromRaw(rawHex);
    await _ensureParentRaws(tx, rawHexByTxid);

    final vout = <Map<String, dynamic>>[];
    for (final o in tx.outputs) {
      var addr = '';
      try {
        addr = o.scriptPubKey.toAddress(network: _network);
      } catch (_) {}
      vout.add({
        'value': o.amount.toInt() / _satsPerBtc,
        'scriptPubKey': {'address': addr},
      });
    }

    final vin = <Map<String, dynamic>>[];
    for (final i in tx.inputs) {
      if (_isNullPreviousOutpoint(i.txId)) {
        vin.add({});
        continue;
      }
      final parentHex = rawHexByTxid[i.txId];
      if (parentHex == null) {
        vin.add({});
        continue;
      }
      try {
        final parent = BtcTransaction.fromRaw(parentHex);
        if (i.txIndex < 0 || i.txIndex >= parent.outputs.length) {
          vin.add({});
          continue;
        }
        final po = parent.outputs[i.txIndex];
        var paddr = '';
        try {
          paddr = po.scriptPubKey.toAddress(network: _network);
        } catch (_) {}
        vin.add({
          'prevout': {
            'value': po.amount.toInt() / _satsPerBtc,
            'scriptPubKey': {'address': paddr},
          },
        });
      } catch (_) {
        vin.add({});
      }
    }

    return {
      'hash': txHash,
      'txid': txHash,
      if (blockHeight > 0) 'height': blockHeight,
      'vout': vout,
      'vin': vin,
    };
  }
}

// ----- Internal value types -----

class _BtcAddress {
  final int index;
  final bool isChange;
  final String address;
  final String scriptHash;
  _BtcAddress({
    required this.index,
    required this.isChange,
    required this.address,
    required this.scriptHash,
  });
}

class _ScripthashState {
  final int confirmed;
  final int unconfirmed;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> unspent;

  /// Status hash reported by the Electrum server at the moment we fetched
  /// [history] / [unspent]. Used to detect stale cache after a push.
  final String? statusAtFetch;
  _ScripthashState({
    required this.confirmed,
    required this.unconfirmed,
    required this.history,
    required this.unspent,
    this.statusAtFetch,
  });
}

class _TxCacheEntry {
  final Map<String, dynamic> verbose;
  final int height;
  final int firstSeenAt;
  final int? broadcastAt;

  _TxCacheEntry({
    required this.verbose,
    required this.height,
    required this.firstSeenAt,
    this.broadcastAt,
  });
}

class _SpendableUtxo {
  final String txHash;
  final int vout;
  final int value;
  final int height;
  final String address;
  final String publicKeyHex;
  final ECPrivate privateKey;

  bool get isConfirmed => height > 0;

  _SpendableUtxo({
    required this.txHash,
    required this.vout,
    required this.value,
    required this.height,
    required this.address,
    required this.publicKeyHex,
    required this.privateKey,
  });

  UtxoWithAddress toUtxoWithAddress(BitcoinNetwork network) {
    return UtxoWithAddress(
      utxo: BitcoinUtxo(
        txHash: txHash,
        value: BigInt.from(value),
        vout: vout,
        scriptType: SegwitAddresType.p2wpkh,
      ),
      ownerDetails: UtxoAddressDetails(
        publicKey: publicKeyHex,
        address: P2wpkhAddress.fromAddress(address: address, network: network),
      ),
    );
  }
}
