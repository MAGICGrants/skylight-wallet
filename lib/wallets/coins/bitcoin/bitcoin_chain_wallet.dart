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
  static const int _gapLimit = 20;
  static const int _satsPerBtc = 100000000;
  static const double _defaultFeeRateSatVb = 5;

  static const int _externalChain = 0;
  static const int _internalChain = 1;

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
       _client = ElectrumClient(coinSymbol: coinSymbol);

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
  DateTime? _restoreDate;

  // ----- Cached chain state (rebuilt on refresh) -----

  /// All HD addresses we have ever generated, in deterministic order.
  /// Index in this list does NOT match the BIP32 key index; use
  /// [_BtcAddress.index] for that. Receive/change chains are tracked
  /// separately via [_BtcAddress.isChange].
  final List<_BtcAddress> _addresses = [];

  /// Latest server-reported scripthash state, keyed by scripthash.
  final Map<String, _ScripthashState> _scripthashState = {};

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
  int get requiredConfirmations => 3;

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
    final file = await _walletFile();
    final blob = (await file.readAsString()).trim();
    final bip84AccountPath = _bip84AccountPath;
    final coinSymbol = _coinSymbol;
    final gapLimit = _gapLimit;
    final externalChain = _externalChain;
    final internalChain = _internalChain;
    final isTestnet = _isTestnet;

    final result = await Isolate.run(
      () => openBitcoinWalletFromEncryptedBlob(
        blob: blob,
        password: password,
        bip84AccountPath: bip84AccountPath,
        coinSymbol: coinSymbol,
        isTestnet: isTestnet,
        gapLimit: gapLimit,
        externalChain: externalChain,
        internalChain: internalChain,
      ),
    );

    _applyOpenResult(result, password);
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
    _accountHd = null;
    _lastPassword = password;
    setIsLoaded(true);
  }

  Bip32Slip10Secp256k1 _requireAccountHd() {
    if (_accountHd != null) return _accountHd!;
    if (_mnemonic == null) {
      throw StateError('Wallet is not loaded.');
    }
    return _accountHd = _deriveAccountHd(_mnemonic!);
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
      'v': 1,
      'mnemonic': _mnemonic,
      'next_receive_index': _nextReceiveIndex,
      'next_change_index': _nextChangeIndex,
      'restore_date_iso': _restoreDate?.toIso8601String(),
    });
    await file.writeAsString(WalletFileCrypto.encryptToBase64(json, password));
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

  @override
  Future<void> deleteFiles() async {
    try {
      await _client.close();
    } catch (_) {}
    final file = await _walletFile();
    if (await file.exists()) await file.delete();
    _mnemonic = null;
    _accountHd = null;
    _lastPassword = null;
    _addresses.clear();
    _scripthashState.clear();
    _txCache.clear();
    _bestHeight = 0;
  }

  // ----- HD derivation -----

  Bip32Slip10Secp256k1 _deriveAccountHd(String mnemonic) {
    final seedBytes = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
    return Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath(_bip84AccountPath)
        as Bip32Slip10Secp256k1;
  }

  /// Re-derives an HD address record at [index] on [chain]. Cheap; no I/O.
  _BtcAddress _generateAddress(int chain, int index) {
    final hd = _requireAccountHd().childKey(Bip32KeyIndex(chain)).childKey(Bip32KeyIndex(index));
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
    for (var i = 0; i < count; i++) {
      if (existing.contains(i)) continue;
      _addresses.add(_generateAddress(chain, i));
    }
  }

  // ----- Connection / refresh -----

  @override
  Future<void> connectToDaemonImpl({
    required String address,
    String? proxyPort,
    required bool useSsl,
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

    walletLog(LogLevel.info, 'Connecting to $host:$port (ssl=$useSsl, socks=$socksPort)');
    await _client.connect(host: host, port: port, useSsl: useSsl, socksPort: socksPort);

    try {
      await _client.serverVersion();
    } catch (e) {
      walletLog(LogLevel.warn, 'server.version failed: $e');
    }

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
  }

  @override
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
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

    try {
      // Walk both chains with gap-limit discovery.
      for (final chain in [_externalChain, _internalChain]) {
        var lastUsed = -1;
        var index = 0;
        while (true) {
          if (!_client.isConnected) return;

          _ensureAddressesUpTo(chain, index + 1);
          final addr = _addressFor(chain, index);
          final scriptHash = addr.scriptHash;

          final history = await _client.getHistory(scriptHash);
          if (history.isNotEmpty) {
            lastUsed = index;
          }

          final balance = await _client.getBalance(scriptHash);
          final unspent = await _client.listUnspent(scriptHash);
          _scripthashState[scriptHash] = _ScripthashState(
            confirmed: balance['confirmed'] ?? 0,
            unconfirmed: balance['unconfirmed'] ?? 0,
            history: history,
            unspent: unspent,
          );

          if (index - lastUsed >= _gapLimit) break;
          index++;
        }

        final nextUnused = lastUsed + 1;
        if (chain == _externalChain) {
          _nextReceiveIndex = nextUnused;
        } else {
          _nextChangeIndex = nextUnused;
        }
      }
    } catch (e) {
      if (isElectrumDisconnectError(e)) {
        walletLog(LogLevel.warn, 'refresh aborted: connection lost');
        return;
      }
      rethrow;
    }
  }

  _BtcAddress _addressFor(int chain, int index) {
    return _addresses.firstWhere(
      (a) => a.index == index && a.isChange == (chain == _internalChain),
    );
  }

  // ----- Stats -----

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
    var sats = 0;
    for (final s in _scripthashState.values) {
      sats += s.confirmed + s.unconfirmed;
    }
    setTotalBalance(sats / _satsPerBtc);
  }

  @override
  Future<void> loadUnlockedBalance() async {
    if (!_client.isConnected) return;
    var sats = 0;
    for (final s in _scripthashState.values) {
      sats += s.confirmed;
    }
    setUnlockedBalance(sats / _satsPerBtc);
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
      final timestamp = _txTimestamp(tx, entry);

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
        ),
      );
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  @override
  Future<void> loadTxHistory({bool persistCount = true}) async {
    if (!_client.isConnected) return;

    // Discover new tx hashes from each scripthash's history; fetch full
    // verbose tx for any we haven't cached yet.
    final newHashes = <String, int>{}; // txHash -> height
    for (final state in _scripthashState.values) {
      for (final entry in state.history) {
        final txHash = entry['tx_hash'] as String?;
        if (txHash == null) continue;
        final height = (entry['height'] as num?)?.toInt() ?? 0;
        newHashes[txHash] = height;
      }
    }

    final rawHexByTxid = <String, String>{};
    for (final entry in newHashes.entries) {
      final cached = _txCache[entry.key];
      if (cached != null && cached.height == entry.value && entry.value > 0) {
        continue;
      }
      if (cached != null && cached.height != entry.value) {
        _txCache[entry.key] = _TxCacheEntry(
          verbose: cached.verbose,
          height: entry.value,
          firstSeenAt: cached.firstSeenAt,
        );
        if (entry.value > 0) {
          continue;
        }
      }
      try {
        final result = await _client.getTransactionBestEffort(entry.key);
        Map<String, dynamic> verbose;
        if (result is Map) {
          verbose = Map<String, dynamic>.from(result);
        } else if (result is String) {
          rawHexByTxid[entry.key] = result;
          verbose = await _verboseMapFromRaw(
            result,
            entry.key,
            rawHexByTxid,
            blockHeight: entry.value,
          );
        } else {
          continue;
        }
        _txCache[entry.key] = _TxCacheEntry(
          verbose: verbose,
          height: entry.value,
          firstSeenAt: cached?.firstSeenAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      } catch (e) {
        if (isElectrumDisconnectError(e)) {
          walletLog(LogLevel.warn, 'loadTxHistory aborted: connection lost');
          break;
        }
        walletLog(LogLevel.warn, 'getTransaction ${entry.key} failed: $e');
      }
    }

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

    await super.loadTxHistory(persistCount: persistCount);
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

    final selection = isSweepAll
        ? _selectAllUtxos(allUtxos)
        : _selectUtxos(allUtxos, amountSats, feeRateSatVb);

    var changeAddress = _nextChangeAddress();
    final outputs = <BitcoinOutput>[];
    int sendAmountSats;
    int feeSats;
    bool hasChange;

    if (isSweepAll) {
      final estSizeNoChange = _estimateVsize(selection.length, 1);
      feeSats = (estSizeNoChange * feeRateSatVb).ceil();
      sendAmountSats = selection.fold<int>(0, (s, u) => s + u.value) - feeSats;
      if (sendAmountSats <= 0) throw Exception('Insufficient funds for fee.');
      outputs.add(BitcoinOutput(address: destAddress, value: BigInt.from(sendAmountSats)));
      hasChange = false;
    } else {
      sendAmountSats = amountSats;
      // Pre-compute fee with change output, then drop change if it would
      // be dust.
      final estSizeWithChange = _estimateVsize(selection.length, 2);
      feeSats = (estSizeWithChange * feeRateSatVb).ceil();
      final inputSum = selection.fold<int>(0, (s, u) => s + u.value);
      final changeSats = inputSum - sendAmountSats - feeSats;
      if (changeSats < 0) {
        throw Exception('Insufficient funds.');
      }

      outputs.add(BitcoinOutput(address: destAddress, value: BigInt.from(sendAmountSats)));
      hasChange = changeSats > 546; // dust threshold
      if (hasChange) {
        outputs.add(
          BitcoinOutput(
            address: P2wpkhAddress.fromAddress(address: changeAddress, network: _network),
            value: BigInt.from(changeSats),
          ),
        );
      } else {
        // Recompute fee for size without change output.
        final estSizeNoChange = _estimateVsize(selection.length, 1);
        feeSats = inputSum - sendAmountSats;
        if (feeSats < (estSizeNoChange * feeRateSatVb).ceil()) {
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

  /// Largest-first selection: simple, deterministic, good enough for v1.
  List<_SpendableUtxo> _selectUtxos(
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
    return 10 + inputs * 68 + outputs * 31;
  }

  Future<double> _resolveFeeRateSatVb(int priority) async {
    final blocks = switch (priority) {
      1 => 25,
      2 => 6,
      3 => 2,
      _ => 6,
    };
    try {
      final btcPerKb = await _client.estimateFee(blocks);
      if (btcPerKb != null) {
        return (btcPerKb * _satsPerBtc / 1000).clamp(1, 1000).toDouble();
      }
    } catch (e) {
      walletLog(LogLevel.warn, 'estimateFee($blocks) failed: $e');
    }
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

  /// Unix seconds for [tx], using verbose fields, cached block time, or
  /// [firstSeenAt] for unconfirmed txs.
  int _txTimestamp(Map<String, dynamic> tx, _TxCacheEntry entry) {
    final fromVerbose = (tx['blocktime'] as num?)?.toInt() ?? (tx['time'] as num?)?.toInt();
    if (fromVerbose != null && fromVerbose > 0) return fromVerbose;

    final blockHeight = _txBlockHeight(tx, entry.height);
    if (blockHeight > 0) {
      final blockTime = _blockTimeByHeight[blockHeight];
      if (blockTime != null && blockTime > 0) return blockTime;
    }

    return entry.firstSeenAt;
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
    for (final height in heights) {
      if (height <= 0 || _blockTimeByHeight.containsKey(height)) continue;
      try {
        final headerHex = await _client.getBlockHeader(height);
        final ts = _timestampFromBlockHeaderHex(headerHex);
        if (ts != null && ts > 0) _blockTimeByHeight[height] = ts;
      } catch (e) {
        if (isElectrumDisconnectError(e)) rethrow;
        walletLog(LogLevel.warn, 'block header $height: $e');
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

  Future<String?> _fetchParentRawHex(String txid, Map<String, String> rawHexByTxid) async {
    final hit = rawHexByTxid[txid];
    if (hit != null) return hit;
    try {
      final r = await _client.getTransaction(txid, verbose: false);
      if (r is String) {
        rawHexByTxid[txid] = r;
        return r;
      }
    } catch (e) {
      if (isElectrumDisconnectError(e)) return null;
      walletLog(LogLevel.warn, 'getTransaction raw parent $txid: $e');
    }
    return null;
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
      final parentHex = await _fetchParentRawHex(i.txId, rawHexByTxid);
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
  _ScripthashState({
    required this.confirmed,
    required this.unconfirmed,
    required this.history,
    required this.unspent,
  });
}

class _TxCacheEntry {
  final Map<String, dynamic> verbose;
  final int height;
  final int firstSeenAt;
  _TxCacheEntry({required this.verbose, required this.height, required this.firstSeenAt});
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
