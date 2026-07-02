import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:blockchain_utils/bip/address/eth_addr.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'package:skylight_wallet/consts.dart' as consts;
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/util/wallet_file_crypto.dart';
import 'package:flutter/foundation.dart' show protected;

import 'package:skylight_wallet/wallets/coins/ethereum/erc20_abi.dart';
import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_explorer_client.dart';
import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_pending_tx.dart';
import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_rpc_client.dart';
import 'package:skylight_wallet/wallets/coins/ethereum/ethereum_wallet_open.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';

part 'erc20_chain_wallet.dart';

/// Account-model EVM wallet backed by a user-supplied JSON-RPC endpoint.
/// Mainnet [`EthereumWallet`] and [`EthereumSepoliaWallet`] differ only by
/// chain id and metadata; the derived address is identical.
class EthereumChainWallet extends CryptoWallet {
  static final BigInt _weiPerEth = BigInt.from(10).pow(18);
  static final RegExp _hexAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static const int _feeInputsTtlMs = 8000;

  EthereumChainWallet({
    required int chainId,
    required String coinSymbol,
    required String coinName,
    required String iconAsset,
    required String connectionAddressExample,
    required bool isTestnet,
  }) : _chainId = chainId,
       _coinSymbol = coinSymbol,
       _coinName = coinName,
       _iconAsset = iconAsset,
       _connectionAddressExample = connectionAddressExample,
       _isTestnet = isTestnet,
       _rpc = EthereumRpcClient(coinSymbol: coinSymbol);

  final int _chainId;
  final String _coinSymbol;
  final String _coinName;
  final String _iconAsset;
  final String _connectionAddressExample;
  final bool _isTestnet;
  final EthereumRpcClient _rpc;
  final EthereumExplorerClient _explorer = EthereumExplorerClient();
  int? _socksPort;

  // In-memory wallet state.
  String? _mnemonic;
  String? _address;
  String? _privateKeyHex; // cached after first derive; cleared on delete
  DateTime? _restoreDate;
  String? _lastPassword;

  // Cached chain state.
  BigInt _balanceWei = BigInt.zero;
  int _bestHeight = 0;
  bool _connected = false;

  /// Shared fee inputs (same across priorities), cached per destination with a
  /// short TTL so the 3-priority preview hits the RPC once, not 3×. Invalidated
  /// after a broadcast (nonce changes).
  ({BigInt baseFee, BigInt tipBase, int nonce, BigInt gasLimit, String to, int atMs})? _feeInputs;

  /// Locally-tracked transactions keyed by hash. Outgoing txs are recorded at
  /// broadcast (no indexer needed); an optional explorer adds incoming ones
  /// later. Confirmations come from polling receipts in [refresh].
  final Map<String, _EthTxRecord> _txRecords = {};

  String get _txRecordsPrefKey => prefKey('cachedEthTxs');

  int get chainId => _chainId;

  // ----- Metadata -----

  @override
  String get coinSymbol => _coinSymbol;
  @override
  String get coinName => _coinName;
  @override
  String get iconAsset => _iconAsset;
  @override
  int get decimals => 10;
  @override
  int get smallerDigits => 6;
  @override
  int get requiredConfirmations => _isTestnet ? 6 : 12;
  @override
  bool get isTestnet => _isTestnet;
  @override
  bool get canSpendPendingBalance => false;
  @override
  bool get canConnectBeforeOpen => true;
  @override
  bool get supportsExplorerUrl => true;
  @override
  String get openAliasAsset => 'eth';
  @override
  String get connectionTypeName => 'RPC endpoint';
  @override
  String get connectionAddressExample => _connectionAddressExample;
  @override
  String get explorerAddressExample =>
      _isTestnet ? 'e.g. eth-sepolia.blockscout.com' : 'e.g. eth.blockscout.com';

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
    final json =
        jsonDecode(await WalletFileCrypto.decryptFromBase64(blob, password))
            as Map<String, dynamic>;
    _mnemonic = json['mnemonic'] as String;
    _address = json['address'] as String?;
    _restoreDate = json['restore_date_iso'] != null
        ? DateTime.tryParse(json['restore_date_iso'] as String)
        : null;
    // Re-derive the address if an older file didn't store it.
    if (_address == null) {
      final mnemonic = _mnemonic!;
      _address = (await Isolate.run(() => deriveEthereumKeys(mnemonic))).address;
    }
    _lastPassword = password;
    setIsLoaded(true);
  }

  @override
  Future<void> restoreFromMasterSeed({
    required String bip39Mnemonic,
    required DateTime restoreDate,
    required String password,
  }) async {
    if (password.isEmpty) throw Exception('Password should not be empty.');
    final mnemonic = bip39Mnemonic;
    final keys = await Isolate.run(() => deriveEthereumKeys(mnemonic));
    _mnemonic = mnemonic;
    _restoreDate = restoreDate;
    _address = keys.address;
    await _persistTo(password);
    setIsLoaded(true);
  }

  Future<void> _persistTo(String password) async {
    _lastPassword = password;
    final file = await _walletFile();
    final json = jsonEncode({
      'mnemonic': _mnemonic,
      'address': _address,
      'restore_date_iso': _restoreDate?.toIso8601String(),
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

  @override
  Future<void> deleteFiles() async {
    final file = await _walletFile();
    if (await file.exists()) await file.delete();
    _mnemonic = null;
    _address = null;
    _privateKeyHex = null;
    _lastPassword = null;
    _balanceWei = BigInt.zero;
    _bestHeight = 0;
    _connected = false;
    _feeInputs = null;
    _txRecords.clear();
  }

  // ----- Connection / refresh -----

  int? _socksPortFrom(String? proxyPort) =>
      (proxyPort != null && proxyPort.isNotEmpty) ? int.tryParse(proxyPort) : null;

  @override
  Future<void> connectToDaemonImpl({
    required String address,
    String? proxyPort,
    required bool useSsl,
  }) async {
    _socksPort = _socksPortFrom(proxyPort);
    _rpc.configure(url: address, socksPort: _socksPort);
    final cid = await _rpc.chainId();
    if (cid != _chainId) {
      throw Exception('RPC is chain id $cid, expected $_chainId ($coinName).');
    }
    _bestHeight = await _rpc.blockNumber();
    _connected = true;
  }

  @override
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
    String connectionType = '',
  }) async {
    final probe = EthereumRpcClient(coinSymbol: coinSymbol)
      ..configure(url: address, socksPort: _socksPortFrom(proxyPort));
    final cid = await probe.chainId();
    if (cid != _chainId) {
      throw Exception('This RPC is chain id $cid, not $_chainId ($coinName).');
    }
  }

  @override
  Future<void> testExplorerConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
  }) async {
    final socks = (proxyPort != null && proxyPort.isNotEmpty) ? int.tryParse(proxyPort) : null;
    await EthereumExplorerClient().probe(address, socksPort: socks);
  }

  /// Resolves the explorer's own SOCKS port (its Tor proxy, or a custom one).
  /// Fails closed: if the explorer requires Tor but none is available, throws
  /// rather than returning null (which would route the request over clearnet).
  Future<int?> _explorerSocksPort() async {
    if (explorerUseTor) {
      final proxy = await TorSettingsService.sharedInstance.getProxy();
      if (proxy == null) {
        throw Exception('explorer requires Tor but no Tor proxy is available');
      }
      return proxy.port;
    }
    return explorerProxyPort.isNotEmpty ? int.tryParse(explorerProxyPort) : null;
  }

  @override
  Future<bool> getIsConnected() async => _rpc.isConfigured && _connected;

  @override
  Future<void> refresh() async {
    if (!_rpc.isConfigured || _address == null) return;
    try {
      _bestHeight = await _rpc.blockNumber();
      _balanceWei = await _rpc.getBalance(_address!);
      _connected = true;
    } catch (e) {
      _connected = false;
      walletLog(LogLevel.warn, 'refresh failed: $e');
      return;
    }

    // Resolve pending txs via their receipts (block + actual fee + status).
    for (final r in _txRecords.values.where((r) => r.blockNumber == 0)) {
      try {
        final receipt = await _rpc.getTransactionReceipt(r.hash);
        if (receipt != null && receipt.blockNumber > 0) {
          r.blockNumber = receipt.blockNumber;
          r.status = receipt.status;
          if (receipt.effectiveGasPrice > BigInt.zero) {
            r.feeWei = receipt.gasUsed * receipt.effectiveGasPrice;
          }
        }
      } catch (e) {
        walletLog(LogLevel.warn, 'receipt ${r.hash}: $e');
      }
    }
  }

  // ----- Stats -----

  double get _balanceEth => _balanceWei.toDouble() / _weiPerEth.toDouble();

  /// Unit a transaction's *amount* is divided by for display (native: wei per
  /// ETH). ERC-20 tokens override to their token-decimal unit. The *fee* always
  /// stays in ETH (`_weiPerEth`).
  @protected
  BigInt get txAmountUnit => _weiPerEth;

  /// Gas limit used when estimation is unavailable or reverts (native transfer
  /// is 21000; ERC-20 transfers override to a safe higher value).
  @protected
  BigInt get fallbackGasLimit => BigInt.from(21000);

  @override
  Future<void> loadIsSynced() async => setIsSynced(_connected && _bestHeight > 0);

  @override
  Future<void> loadSyncedHeight() async => setSyncedHeight(_bestHeight > 0 ? _bestHeight : null);

  @override
  Future<void> loadTotalBalance() async {
    if (!_connected) return;
    setTotalBalance(_balanceEth);
  }

  @override
  Future<void> loadUnlockedBalance() async {
    if (!_connected) return;
    setUnlockedBalance(_balanceEth);
  }

  @override
  Future<int> getCurrentHeight() async => _bestHeight;

  @override
  Future<int> getRestoreHeight() async => 0;

  // ----- Tx history -----

  @override
  List<TxDetails> readTxHistory() {
    final tip = _bestHeight;
    final entries = _txRecords.values.map((r) {
      final confirmations = r.blockNumber > 0 && tip >= r.blockNumber ? tip - r.blockNumber + 1 : 0;
      final amountUnits = r.valueWei.toDouble() / txAmountUnit.toDouble();
      return TxDetails(
        index: null,
        direction: r.direction,
        hash: r.hash,
        amount: amountUnits,
        fee: r.feeWei.toDouble() / _weiPerEth.toDouble(),
        // The recipient is the destination of the transfer: for outgoing it's
        // the address we sent to; for incoming it's us. (The record's `to` field
        // historically held the sender for incoming, which is 0x0 for mints, so
        // resolve incoming to our own address at display time.)
        recipients: [
          TxRecipient(
            r.direction == consts.txDirectionOutgoing ? r.to : (_address ?? r.to),
            amountUnits,
          ),
        ],
        accountIndex: 0,
        subaddrIndexList: const [],
        timestamp: r.timestamp,
        height: r.blockNumber > 0 ? r.blockNumber : -1,
        confirmations: confirmations,
        key: '',
        broadcastAt: r.direction == consts.txDirectionOutgoing ? r.timestamp : null,
      );
    }).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  @override
  Future<void> loadTxHistory({bool persistCount = true}) async {
    // Optional explorer fills in incoming + historical txs (RPC can't list an
    // address's history). Local records (current outgoing) take precedence.
    if (explorerAddress.isNotEmpty && _address != null) {
      try {
        final socks = await _explorerSocksPort();
        final txs = await fetchExplorerTransfers(socks);
        final me = _address!.toLowerCase();
        for (final t in txs) {
          final isOut = t.from.toLowerCase() == me;
          _txRecords.putIfAbsent(
            t.hash,
            () => _EthTxRecord(
              hash: t.hash,
              direction: isOut ? consts.txDirectionOutgoing : consts.txDirectionIncoming,
              to: isOut ? t.to : t.from,
              valueWei: t.valueWei,
              feeWei: isOut ? t.feeWei : BigInt.zero,
              blockNumber: t.blockNumber,
              status: t.status,
              timestamp: t.timestamp,
            ),
          );
        }
      } catch (e) {
        walletLog(LogLevel.warn, 'explorer history fetch failed: $e');
      }
    }
    await super.loadTxHistory(persistCount: persistCount);
  }

  /// Address history from the explorer. Native ETH transfers by default;
  /// ERC-20 tokens override to fetch token transfers for their contract.
  @protected
  Future<List<ExplorerTx>> fetchExplorerTransfers(int? socksPort) =>
      _explorer.fetchTxList(explorerAddress, _address!, socksPort: socksPort);

  // ----- Send / receive -----

  @override
  String getPrimaryAddress() => _address ?? '';

  @override
  String? getReceiveAddress() => _address;

  @override
  bool isAddressValid(String address) {
    if (!_hexAddress.hasMatch(address)) return false;
    final body = address.substring(2);
    final mixedCase = body.contains(RegExp(r'[a-f]')) && body.contains(RegExp(r'[A-F]'));
    if (!mixedCase) return true; // all-lower or all-upper: no checksum to verify
    try {
      return EthAddrUtils.toChecksumAddress(address) == address;
    } catch (_) {
      return false;
    }
  }

  /// Gas for the send. A native transfer is 21000; estimate (to also cover
  /// contract recipients) with a 1-wei probe so it never reverts on
  /// insufficient funds, falling back to 21000 if the node refuses.
  Future<BigInt> _resolveGasLimit(String from, String to, {String? data}) async {
    try {
      final est = await _rpc.estimateGas(
        from: from,
        to: to,
        value: data == null ? BigInt.one : BigInt.zero,
        data: data,
      );
      return est > BigInt.zero ? est : fallbackGasLimit;
    } catch (e) {
      walletLog(LogLevel.warn, 'estimateGas fallback to $fallbackGasLimit: $e');
      return fallbackGasLimit;
    }
  }

  /// Signing credentials, deriving (and caching) the private key once. The
  /// PBKDF2 runs in an isolate; capture a LOCAL mnemonic so the closure doesn't
  /// capture `this` (whose base-class Timers are unsendable to the isolate).
  Future<EthPrivateKey> _credentials() async {
    if (_privateKeyHex == null) {
      final mnemonic = _mnemonic!;
      _privateKeyHex = (await Isolate.run(() => deriveEthereumKeys(mnemonic))).privateKeyHex;
    }
    return EthPrivateKey.fromHex(_privateKeyHex!);
  }

  /// Fetches the priority-independent fee inputs (base fee, tip suggestion,
  /// nonce, gas limit), reusing a cached set within [_feeInputsTtlMs] for the
  /// same destination so each priority doesn't re-hit the RPC.
  Future<({BigInt baseFee, BigInt tipBase, int nonce, BigInt gasLimit})> _resolveFeeInputs(
    String from,
    String to, {
    String? data,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _feeInputs;
    if (cached != null && cached.to == to && now - cached.atMs < _feeInputsTtlMs) {
      return (
        baseFee: cached.baseFee,
        tipBase: cached.tipBase,
        nonce: cached.nonce,
        gasLimit: cached.gasLimit,
      );
    }
    final baseFee = await _rpc.baseFeePerGas();
    final tipBase = await _rpc.maxPriorityFeePerGas();
    final nonce = await _rpc.getTransactionCount(from);
    final gasLimit = await _resolveGasLimit(from, to, data: data);
    _feeInputs = (
      baseFee: baseFee,
      tipBase: tipBase,
      nonce: nonce,
      gasLimit: gasLimit,
      to: to,
      atMs: now,
    );
    return (baseFee: baseFee, tipBase: tipBase, nonce: nonce, gasLimit: gasLimit);
  }

  BigInt _scaleTip(BigInt suggested, int priority) {
    final tipFloor = suggested > BigInt.zero ? suggested : BigInt.from(1000000000); // 1 gwei floor
    final mult = switch (priority) {
      1 => 1, // low
      3 => 3, // high
      _ => 2, // normal / default
    };
    return tipFloor * BigInt.from(mult);
  }

  @override
  Future<PendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority = 0,
  }) async {
    walletLog(
      LogLevel.info,
      'createTx: amount=$amount sweep=$isSweepAll prio=$priority '
      'loaded=${_address != null} configured=${_rpc.isConfigured} '
      'connected=$_connected balanceWei=$_balanceWei',
    );
    if (_mnemonic == null || _address == null) throw Exception('Wallet is not loaded.');
    if (!_rpc.isConfigured) throw Exception('Not connected to an RPC endpoint.');
    if (!isAddressValid(destinationAddress)) {
      walletLog(LogLevel.warn, 'createTx: invalid address "$destinationAddress"');
      throw Exception('Invalid Ethereum address.');
    }

    final from = _address!;

    // EIP-1559 (type-2) fees. Base fee, tip suggestion, nonce, and gas limit
    // are the same across priorities → fetched once and cached; only the tip
    // is re-scaled here.
    final ({BigInt baseFee, BigInt tipBase, int nonce, BigInt gasLimit}) inputs;
    try {
      inputs = await _resolveFeeInputs(from, destinationAddress);
    } catch (e) {
      walletLog(LogLevel.warn, 'createTx fee RPC failed: $e');
      rethrow;
    }
    final tip = _scaleTip(inputs.tipBase, priority);
    final maxFeePerGas = inputs.baseFee * BigInt.two + tip;
    final nonce = inputs.nonce;
    final gasLimit = inputs.gasLimit;
    final maxFeeTotal = gasLimit * maxFeePerGas;

    BigInt valueWei;
    if (isSweepAll) {
      valueWei = _balanceWei - maxFeeTotal;
      if (valueWei <= BigInt.zero) {
        walletLog(LogLevel.info, 'sweep too low: balance $_balanceWei < fee $maxFeeTotal');
        throw Exception('Unlocked funds too low');
      }
    } else {
      valueWei = BigInt.from((amount * _weiPerEth.toDouble()).round());
      if (valueWei + maxFeeTotal > _balanceWei) {
        walletLog(
          LogLevel.info,
          'insufficient: value $valueWei + fee $maxFeeTotal > balance $_balanceWei',
        );
        throw Exception('Unlocked funds too low');
      }
    }

    // Offline build + sign (no network: nonce/gas/fees/chainId all supplied).
    final Uint8List signed;
    try {
      final credentials = await _credentials();
      final tx = Transaction(
        from: credentials.address,
        to: EthereumAddress.fromHex(destinationAddress),
        value: EtherAmount.inWei(valueWei),
        maxGas: gasLimit.toInt(),
        maxPriorityFeePerGas: EtherAmount.inWei(tip),
        maxFeePerGas: EtherAmount.inWei(maxFeePerGas),
        nonce: nonce,
      );
      signed = await Web3Client(
        _rpc.url!,
        http.Client(),
      ).signTransaction(credentials, tx, chainId: _chainId);
      final head = bytesToHex(signed);
      walletLog(
        LogLevel.info,
        'createTx signed ok (${signed.length}b) head=0x${head.substring(0, head.length < 8 ? head.length : 8)} to=$destinationAddress',
      );
    } catch (e) {
      walletLog(LogLevel.warn, 'eth build/sign failed: $e');
      rethrow;
    }

    // web3dart returns the EIP-1559 body without the EIP-2718 type byte; a
    // valid type-2 tx is `0x02 || rlp(...)`. Prepend it when the output is a
    // bare RLP list (>= 0xc0) so the node decodes type-2, not legacy.
    final raw = (signed.isNotEmpty && signed[0] >= 0xc0)
        ? Uint8List.fromList([0x02, ...signed])
        : signed;

    return EthereumPendingTx(
      amount: valueWei.toDouble() / _weiPerEth.toDouble(),
      fee: maxFeeTotal.toDouble() / _weiPerEth.toDouble(),
      valueWei: valueWei,
      feeWei: maxFeeTotal,
      rawHex: '0x${bytesToHex(raw)}',
      txHash: '0x${bytesToHex(keccak256(raw))}',
      to: destinationAddress,
    );
  }

  @override
  Future<void> commitTx(PendingTransaction tx, String destinationAddress) async {
    if (tx is! EthereumPendingTx) {
      throw ArgumentError('EthereumChainWallet.commitTx requires an EthereumPendingTx');
    }
    final hash = await _rpc.sendRawTransaction(tx.rawHex);
    walletLog(LogLevel.info, 'broadcast ok: $hash');
    _feeInputs = null; // nonce advanced; force a fresh fetch next time

    _txRecords[tx.txHash] = _EthTxRecord(
      hash: tx.txHash,
      direction: consts.txDirectionOutgoing,
      to: tx.to,
      valueWei: tx.valueWei,
      feeWei: tx.feeWei,
      blockNumber: 0,
      status: -1,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    try {
      await refresh();
      await loadTxHistory();
    } catch (e) {
      walletLog(LogLevel.warn, 'post-broadcast refresh failed: $e');
    }
  }

  // ----- Snapshot persistence -----

  @override
  Future<void> persistWalletSnapshot() async {
    await super.persistWalletSnapshot();
    if (_txRecords.isEmpty) return;
    try {
      final json = jsonEncode({
        'txs': [for (final r in _txRecords.values) r.toJson()],
      });
      await SharedPreferencesService.set<String>(_txRecordsPrefKey, json);
    } catch (e) {
      walletLog(LogLevel.warn, 'persist eth txs: $e');
    }
  }

  @override
  Future<void> loadPersistedSnapshot() async {
    await super.loadPersistedSnapshot();
    try {
      final raw = await SharedPreferencesService.get<String>(_txRecordsPrefKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      final txs = decoded is Map ? decoded['txs'] : null;
      if (txs is! List) return;
      for (final t in txs) {
        if (t is! Map) continue;
        final r = _EthTxRecord.fromJson(t.cast<String, dynamic>());
        if (r != null) _txRecords[r.hash] = r;
      }
    } catch (e) {
      walletLog(LogLevel.warn, 'load eth txs: $e');
    }
  }

  @override
  Future<void> clearPersistedState() async {
    await super.clearPersistedState();
    await SharedPreferencesService.remove(_txRecordsPrefKey);
  }
}

/// Locally-tracked Ethereum transaction (outgoing recorded at broadcast;
/// incoming added by the optional explorer). Mutable fields are updated when
/// the receipt resolves.
class _EthTxRecord {
  _EthTxRecord({
    required this.hash,
    required this.direction,
    required this.to,
    required this.valueWei,
    required this.feeWei,
    required this.blockNumber,
    required this.status,
    required this.timestamp,
  });

  final String hash;
  final int direction;
  final String to;
  final BigInt valueWei;
  BigInt feeWei;
  int blockNumber; // 0 = pending
  int status; // 1 success, 0 failed, -1 unknown
  final int timestamp; // unix seconds (broadcast time, or block time from explorer)

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'direction': direction,
    'to': to,
    'value_wei': valueWei.toString(),
    'fee_wei': feeWei.toString(),
    'block': blockNumber,
    'status': status,
    'ts': timestamp,
  };

  static _EthTxRecord? fromJson(Map<String, dynamic> j) {
    final hash = j['hash'] as String?;
    if (hash == null) return null;
    return _EthTxRecord(
      hash: hash,
      direction: (j['direction'] as num?)?.toInt() ?? consts.txDirectionOutgoing,
      to: j['to'] as String? ?? '',
      valueWei: BigInt.tryParse(j['value_wei'] as String? ?? '0') ?? BigInt.zero,
      feeWei: BigInt.tryParse(j['fee_wei'] as String? ?? '0') ?? BigInt.zero,
      blockNumber: (j['block'] as num?)?.toInt() ?? 0,
      status: (j['status'] as num?)?.toInt() ?? -1,
      timestamp: (j['ts'] as num?)?.toInt() ?? 0,
    );
  }
}
