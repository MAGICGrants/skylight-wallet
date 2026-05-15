import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'package:skylight_wallet/wallets/coins/bitcoin/electrum_client.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

/// BIP84 (P2WPKH) Bitcoin wallet backed by a user-supplied Electrum server.
///
/// Built on `bitcoin_base` (HD derivation, address generation, transaction
/// building/signing) plus our own thin [ElectrumClient]. Persists a single
/// AES-encrypted JSON file containing the BIP39 mnemonic and the next-unused
/// address indices on each chain.
class BitcoinWallet extends CryptoWallet {
  static const String _accountPath = "m/84'/0'/0'";
  static const int _gapLimit = 20;
  static const int _satsPerBtc = 100000000;
  static const double _defaultFeeRateSatVb = 5;

  static const int _externalChain = 0;
  static const int _internalChain = 1;

  final BitcoinNetwork _network = BitcoinNetwork.mainnet;
  final ElectrumClient _client = ElectrumClient();

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

  int _bestHeight = 0;
  int _nextReceiveIndex = 0;
  int _nextChangeIndex = 0;

  // ----- CryptoWallet metadata -----

  @override
  String get coinSymbol => 'BTC';

  @override
  String get coinName => 'Bitcoin';

  @override
  String get iconAsset => 'assets/icons/bitcoin.svg';

  @override
  int get decimals => 8;

  @override
  int get smallerDigits => 3;

  @override
  String get connectionTypeName => 'Electrum server';

  @override
  String get connectionAddressExample => 'e.g. electrum.example.com:50002';

  // ----- Persistence -----

  Future<File> _walletFile() async => File(await getWalletPath(coinSymbol));

  @override
  Future<bool> hasExistingWallet() async => (await _walletFile()).exists();

  @override
  Future<void> openExisting({required String password}) async {
    final file = await _walletFile();
    final blob = await file.readAsString();
    final json =
        jsonDecode(WalletFileCrypto.decryptFromBase64(blob, password)) as Map<String, dynamic>;

    _mnemonic = json['mnemonic'] as String;
    _restoreDate = DateTime.tryParse(json['restore_date_iso'] as String? ?? '');
    _nextReceiveIndex = (json['next_receive_index'] as num?)?.toInt() ?? 0;
    _nextChangeIndex = (json['next_change_index'] as num?)?.toInt() ?? 0;

    _accountHd = _deriveAccountHd(_mnemonic!);
    _ensureAddressesUpTo(_externalChain, _nextReceiveIndex + _gapLimit);
    _ensureAddressesUpTo(_internalChain, _nextChangeIndex + _gapLimit);

    _lastPassword = password;
    setIsLoaded(true);
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

    _mnemonic = bip39Mnemonic;
    _restoreDate = restoreDate;
    _nextReceiveIndex = 0;
    _nextChangeIndex = 0;
    _accountHd = _deriveAccountHd(bip39Mnemonic);

    _addresses.clear();
    _ensureAddressesUpTo(_externalChain, _gapLimit);
    _ensureAddressesUpTo(_internalChain, _gapLimit);

    setIsLoaded(true);
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
      log(LogLevel.warn, '[BTC] store failed: $e');
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
    return Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath(_accountPath)
        as Bip32Slip10Secp256k1;
  }

  /// Re-derives an HD address record at [index] on [chain]. Cheap; no I/O.
  _BtcAddress _generateAddress(int chain, int index) {
    final hd = _accountHd!.childKey(Bip32KeyIndex(chain)).childKey(Bip32KeyIndex(index));
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
    if (_accountHd == null) return;
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

    log(LogLevel.info, '[BTC] Connecting to $host:$port (ssl=$useSsl, socks=$socksPort)');
    await _client.connect(host: host, port: port, useSsl: useSsl, socksPort: socksPort);

    try {
      await _client.serverVersion();
    } catch (e) {
      log(LogLevel.warn, '[BTC] server.version failed: $e');
    }

    try {
      final initialHeader = await _client.subscribeHeaders((header) {
        final h = (header['height'] as num?)?.toInt();
        if (h != null && h > _bestHeight) {
          _bestHeight = h;
        }
      });
      final h = (initialHeader['height'] as num?)?.toInt();
      if (h != null) _bestHeight = h;
    } catch (e) {
      log(LogLevel.warn, '[BTC] header subscribe failed: $e');
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

    log(LogLevel.info, '[BTC] Probing $host:$port (ssl=$useSsl, socks=$socksPort)');
    await probeElectrumServer(host: host, port: port, useSsl: useSsl, socksPort: socksPort);
  }

  @override
  Future<bool> getIsConnected() async => _client.isConnected;

  @override
  Future<void> refresh() async {
    if (_accountHd == null || !_client.isConnected) return;

    // Walk both chains with gap-limit discovery.
    for (final chain in const [_externalChain, _internalChain]) {
      var lastUsed = -1;
      var index = 0;
      while (true) {
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
    var sats = 0;
    for (final s in _scripthashState.values) {
      sats += s.confirmed + s.unconfirmed;
    }
    setTotalBalance(sats / _satsPerBtc);
  }

  @override
  Future<void> loadUnlockedBalance() async {
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

      final vouts = (tx['vout'] as List?) ?? const [];
      final vins = (tx['vin'] as List?) ?? const [];

      var inputsFromUs = 0;
      var inputsFromUsValueSats = 0;
      for (final vin in vins) {
        if (vin is! Map) continue;
        final prev = vin['prevout'];
        if (prev is Map) {
          final prevAddr = _addressFromScriptPubKey(prev);
          if (prevAddr != null && ourAddresses.contains(prevAddr)) {
            inputsFromUs++;
            final v = (prev['value'] as num?)?.toDouble();
            if (v != null) inputsFromUsValueSats += _btcToSats(v);
          }
        }
      }
      final isOutgoing = inputsFromUs > 0;

      var outputsToUsSats = 0;
      var outputsToOthersSats = 0;
      final recipients = <TxRecipient>[];
      for (final vout in vouts) {
        if (vout is! Map) continue;
        final scriptPubKey = vout['scriptPubKey'];
        final addr = scriptPubKey is Map ? _addressFromScriptPubKey(scriptPubKey) : null;
        final valueBtc = (vout['value'] as num?)?.toDouble() ?? 0;
        final valueSats = _btcToSats(valueBtc);
        if (addr != null && ourAddresses.contains(addr)) {
          outputsToUsSats += valueSats;
        } else {
          outputsToOthersSats += valueSats;
          if (addr != null) {
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
      }

      final height =
          (tx['height'] as num?)?.toInt() ??
          (tx['confirmations'] is num
              ? _bestHeight - (tx['confirmations'] as num).toInt() + 1
              : -1);
      final confirmations = height > 0 && _bestHeight > 0 ? _bestHeight - height + 1 : 0;
      final timestamp =
          (tx['time'] as num?)?.toInt() ?? (tx['blocktime'] as num?)?.toInt() ?? entry.firstSeenAt;

      entries.add(
        TxDetails(
          index: null,
          direction: isOutgoing ? consts.txDirectionOutgoing : consts.txDirectionIncoming,
          hash: hash,
          amount: amountSats / _satsPerBtc,
          fee: feeSats / _satsPerBtc,
          recipients: isOutgoing ? recipients : const [],
          accountIndex: 0,
          subaddrIndexList: const [],
          timestamp: timestamp,
          height: height,
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

    for (final entry in newHashes.entries) {
      final cached = _txCache[entry.key];
      if (cached != null && cached.height == entry.value && cached.height > 0) {
        continue;
      }
      try {
        final verbose = await _client.getTransaction(entry.key, verbose: true);
        if (verbose is Map) {
          _txCache[entry.key] = _TxCacheEntry(
            verbose: Map<String, dynamic>.from(verbose),
            height: entry.value,
            firstSeenAt: cached?.firstSeenAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
        }
      } catch (e) {
        log(LogLevel.warn, '[BTC] getTransaction ${entry.key} failed: $e');
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
    if (_accountHd == null) {
      throw StateError('Wallet is not loaded.');
    }

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

    final builderUtxos = selection.map((u) => u.toUtxoWithAddress()).toList();
    final txb = BitcoinTransactionBuilder(
      utxos: builderUtxos,
      outputs: outputs,
      fee: BigInt.from(feeSats),
      network: _network,
      outputOrdering: BitcoinOrdering.none,
      enableRBF: true,
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
      throw ArgumentError('BitcoinWallet.commitTx requires a BitcoinPendingTx');
    }
    final txid = await _client.broadcastTransaction(tx.rawHex);
    log(LogLevel.info, '[BTC] broadcast ok: $txid');

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

    await refresh();
    await loadTxHistory();
  }

  // ----- Coin selection -----

  List<_SpendableUtxo> _collectSpendableUtxos() {
    final out = <_SpendableUtxo>[];
    for (final addr in _addresses) {
      final state = _scripthashState[addr.scriptHash];
      if (state == null) continue;
      final hd = _accountHd!
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
      < 0 => 25,
      0 => 6,
      _ => 2,
    };
    try {
      final btcPerKb = await _client.estimateFee(blocks);
      if (btcPerKb != null) {
        return (btcPerKb * _satsPerBtc / 1000).clamp(1, 1000).toDouble();
      }
    } catch (e) {
      log(LogLevel.warn, '[BTC] estimateFee($blocks) failed: $e');
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
  /// either `addresses: [..]` or a singular `address`.
  String? _addressFromScriptPubKey(Map<dynamic, dynamic> script) {
    final direct = script['address'];
    if (direct is String) return direct;
    final list = script['addresses'];
    if (list is List && list.isNotEmpty && list.first is String) {
      return list.first as String;
    }
    return null;
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
  final String address;
  final String publicKeyHex;
  final ECPrivate privateKey;

  _SpendableUtxo({
    required this.txHash,
    required this.vout,
    required this.value,
    required this.address,
    required this.publicKeyHex,
    required this.privateKey,
  });

  UtxoWithAddress toUtxoWithAddress() {
    return UtxoWithAddress(
      utxo: BitcoinUtxo(
        txHash: txHash,
        value: BigInt.from(value),
        vout: vout,
        scriptType: SegwitAddresType.p2wpkh,
      ),
      ownerDetails: UtxoAddressDetails(
        publicKey: publicKeyHex,
        address: P2wpkhAddress.fromAddress(address: address, network: BitcoinNetwork.mainnet),
      ),
    );
  }
}
