// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:bip39/bip39.dart' as bip39;
import 'package:http/http.dart' as http;
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/monero.dart' as monero_ffi;
import 'package:monero/src/wallet2.dart';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
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
  final _w2WalletManager = monero_ffi.Monero().walletManagerFactory().getLWSFWalletManager();

  Wallet2Wallet? _w2Wallet;
  Wallet2TransactionHistory? _w2TxHistory;

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
  String get connectionTypeName => 'Monero LWS server';

  @override
  String get connectionAddressExample => 'e.g. 192.168.1.1:18090 or example.com:18090';

  // ----- Lifecycle -----

  @override
  Future<bool> hasExistingWallet() async {
    final path = await getWalletPath(coinSymbol);

    log(LogLevel.info, 'Calling WalletManager_walletExists with parameters:');
    log(LogLevel.info, '  path: $path');

    final exists = _w2WalletManager.walletExists(path);

    log(LogLevel.info, 'WalletManager_walletExists result: $exists');

    final errorString = _w2WalletManager.errorString();
    if (errorString != '') {
      log(LogLevel.error, 'WalletManager_walletExists error: $errorString');
    }

    return exists;
  }

  @override
  Future<void> openExisting({required String password}) async {
    final path = await getWalletPath(coinSymbol);

    log(LogLevel.info, 'Calling WalletManager_openWallet with parameters:');
    log(LogLevel.info, '  path: $path');
    log(LogLevel.info, '  password: <hidden>');

    final w2Wallet = _w2WalletManager.openWallet(path: path, password: password);

    if (w2Wallet.errorString() != '') {
      final errorMsg = 'WalletManager_openWallet error: ${w2Wallet.errorString()}';
      log(LogLevel.error, errorMsg);
      throw Exception(errorMsg);
    }

    log(LogLevel.info, 'WalletManager_openWallet completed');

    _w2Wallet = w2Wallet;
    _w2TxHistory = _w2Wallet!.history();

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

    final legacyMnemonic = getLegacySeedFromBip39(bip39Mnemonic);
    final restoreHeight = getHeightByDate(date: restoreDate);

    log(LogLevel.info, '[XMR] Using blockchain height: $restoreHeight');

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

      log(LogLevel.error, 'Error restoring from mnemonic: ${wallet.errorString()}');
      throw Exception('Error restoring from mnemonic: ${wallet.errorString()}');
    }

    _w2Wallet = wallet;
    _w2TxHistory = _w2Wallet!.history();

    await SharedPreferencesService.set<int>(prefKey('walletRestoreHeight'), restoreHeight);

    setIsLoaded(true);
    await store();
  }

  Future<monero_ffi.MoneroWallet> _walletFromLegacySeed({
    required String mnemonic,
    required int restoreHeight,
    required String password,
  }) async {
    final wmFfiAddr = _w2WalletManager.ffiAddress();
    final walletPath = await getWalletPath(coinSymbol);

    log(LogLevel.info, 'Calling WalletManager_recoveryWallet with parameters:');
    log(LogLevel.info, '  mnemonic: <hidden>');
    log(LogLevel.info, '  restoreHeight: $restoreHeight');
    log(LogLevel.info, '  password: <hidden>');
    log(LogLevel.info, '  path: $walletPath');

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

    log(LogLevel.info, 'WalletManager_recoveryWallet completed');

    return monero_ffi.MoneroWallet(Pointer<Void>.fromAddress(walletFfiAddr));
  }

  @override
  Future<bool> store() async {
    if (_w2Wallet == null) return false;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    log(LogLevel.info, 'Calling Wallet_store');

    final result = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_store(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_store result: $result');
    return result;
  }

  @override
  Future<void> deleteFiles() async {
    if (_w2Wallet != null) {
      _w2WalletManager.closeWallet(_w2Wallet!, false);
      _w2Wallet = null;
      _w2TxHistory = null;
    }

    final path = await getWalletPath(coinSymbol);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
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

    if (Platform.isAndroid) {
      // Addresses SSL certificate verification issues on Android.
      final cacertFile = await getCacertFile();
      _w2Wallet!.setCaFilePath(cacertFile.path);
    }

    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final daemonAddress = '${useSsl ? 'https://' : 'http://'}$address';
    final proxyAddress = proxyPort != null && proxyPort != '' ? '127.0.0.1:$proxyPort' : '';
    const lightWallet = true;

    log(LogLevel.info, 'Calling Wallet_init with parameters:');
    log(LogLevel.info, '  daemonAddress: $daemonAddress');
    log(LogLevel.info, '  proxyAddress: $proxyAddress');
    log(LogLevel.info, '  useSsl: $useSsl');
    log(LogLevel.info, '  lightWallet: $lightWallet');

    final initResult = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_init(
        Pointer.fromAddress(walletFfiAddr),
        daemonAddress: daemonAddress,
        proxyAddress: proxyAddress,
        useSsl: useSsl,
        lightWallet: lightWallet,
      ),
    );

    log(LogLevel.info, 'Wallet_init result: $initResult');

    final connectResult = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connectToDaemon(Pointer.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_connectToDaemon result: $connectResult');

    final connectError = _w2Wallet!.errorString();
    if (connectError != '') {
      log(LogLevel.warn, 'Wallet_connectToDaemon error: $connectError');
    }
  }

  @override
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
  }) async {
    final url = '${useSsl ? 'https' : 'http'}://$address/get_address_info';
    log(LogLevel.info, '[XMR] Probing LWS server: $url (tor=$useTor, proxyPort=$proxyPort)');

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
      ).timeout(const Duration(seconds: 20));
      statusCode = response.statusCode;
    } else {
      var httpClient = HttpClient();
      if (proxyPort != null && proxyPort.isNotEmpty) {
        httpClient.findProxy = (_) => 'PROXY localhost:$proxyPort';
      }
      try {
        final request = await httpClient.postUrl(Uri.parse(url));
        final response = await request.close().timeout(const Duration(seconds: 10));
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

  @override
  Future<bool> getIsConnected() async {
    if (_w2Wallet == null) return false;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    final connected = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_connected(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    return connected != 0;
  }

  @override
  Future<void> refresh() async {
    if (_w2Wallet == null || _w2TxHistory == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    final historyFfiAddr = _w2TxHistory!.ffiAddress();

    log(
      LogLevel.info,
      'Calling Wallet_startRefresh, Wallet_refresh, and TransactionHistory_refresh',
    );

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

  @override
  Future<void> loadIsSynced() async {
    if (_w2Wallet == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    log(LogLevel.info, 'Calling Wallet_synchronized:');

    final synced = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_synchronized(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_synchronized result: $synced');
    setIsSynced(synced);
  }

  @override
  Future<void> loadSyncedHeight() async {
    if (_w2Wallet == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    log(LogLevel.info, 'Calling Wallet_blockChainHeight:');

    final height = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.Wallet_blockChainHeight(Pointer<Void>.fromAddress(walletFfiAddr)),
    );

    log(LogLevel.info, 'Wallet_blockChainHeight result: $height');
    setSyncedHeight(height);
  }

  @override
  Future<void> loadTotalBalance() async {
    if (_w2Wallet == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    const accountIndex = 0;

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
    setTotalBalance(doubleAmountFromInt(amount));
  }

  @override
  Future<void> loadUnlockedBalance() async {
    if (_w2Wallet == null) return;
    final walletFfiAddr = _w2Wallet!.ffiAddress();
    const accountIndex = 0;

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
    setUnlockedBalance(doubleAmountFromInt(amount));
  }

  @override
  Future<int> getCurrentHeight() async {
    final wmFfiAddr = _w2WalletManager.ffiAddress();

    log(LogLevel.info, 'Calling WalletManager_blockchainHeight');

    final height = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.WalletManager_blockchainHeight(Pointer.fromAddress(wmFfiAddr));
    });

    log(LogLevel.info, 'WalletManager_blockchainHeight result: $height');
    return height;
  }

  @override
  Future<int> getRestoreHeight() async {
    if (_w2Wallet == null) {
      return await SharedPreferencesService.get<int>(prefKey('walletRestoreHeight')) ?? 0;
    }

    log(LogLevel.info, 'Calling Wallet_getRefreshFromBlockHeight');
    final w2RestoreHeight = _w2Wallet!.getRefreshFromBlockHeight();
    log(LogLevel.info, 'Wallet_getRefreshFromBlockHeight result: $w2RestoreHeight');

    if (w2RestoreHeight > 0) {
      return w2RestoreHeight;
    }

    return await SharedPreferencesService.get<int>(prefKey('walletRestoreHeight')) ?? 0;
  }

  @override
  List<TxDetails> readTxHistory() {
    if (_w2TxHistory == null || _w2Wallet == null) return [];

    final txCount = _w2TxHistory!.count();
    final List<TxDetails> txs = [];

    for (int i = 0; i < txCount; i++) {
      txs.add(_buildTxDetails(i));
    }

    txs.sort((a, b) => a.timestamp < b.timestamp ? 1 : -1);
    return txs;
  }

  TxDetails _buildTxDetails(int txIndex) {
    final tx = _w2TxHistory!.transaction(txIndex);
    final direction = tx.direction();
    final hash = tx.hash();
    final amountSent = doubleAmountFromInt(tx.amount());
    final fee = doubleAmountFromInt(tx.fee());
    final timestamp = tx.timestamp();
    final height = tx.blockHeight();
    final confirmations = height > -1 ? _w2Wallet!.blockChainHeight() - height + 1 : 0;
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
    const accountIndex = 0;

    log(LogLevel.info, 'Calling Wallet_address with parameters:');
    log(LogLevel.info, '  accountIndex: $accountIndex');

    final address = _w2Wallet!.address(accountIndex: accountIndex);

    log(LogLevel.info, 'Wallet_address result: $address');
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

    log(LogLevel.info, 'Calling Wallet_address with parameters:');
    log(LogLevel.info, '  accountIndex: 0');
    log(LogLevel.info, '  addressIndex: $subaddrIndex');

    final subaddress = _w2Wallet!.address(accountIndex: 0, addressIndex: subaddrIndex);

    log(LogLevel.info, 'Wallet_address result: $subaddress');
    return subaddress;
  }

  @override
  Future<PendingTransaction> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority = 0,
  }) async {
    final amountInt = _w2Wallet!.amountFromDouble(amount);
    final walletFfiAddr = _w2Wallet!.ffiAddress();

    final dstAddr = [destinationAddress];
    final amounts = [amountInt];
    const mixinCount = 15;
    const subaddrAccount = 0;

    log(LogLevel.info, 'Calling Wallet_createTransactionMultDest with parameters:');
    log(LogLevel.info, '  walletFfiAddr: $walletFfiAddr');
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

    log(LogLevel.info, 'Wallet_createTransactionMultDest completed');

    final pendingTx = monero_ffi.MoneroPendingTransaction(txPointer);

    if (pendingTx.errorString() != '') {
      log(LogLevel.error, 'Failed to create transaction: ${pendingTx.errorString()}');
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

    log(LogLevel.info, 'Calling PendingTransaction_commit with parameters:');
    log(LogLevel.info, '  filename: ');
    log(LogLevel.info, '  overwrite: false');

    final commitResult = await Isolate.run(() {
      // ignore: deprecated_member_use
      return monero.PendingTransaction_commit(
        Pointer.fromAddress(txFfiAddr),
        filename: '',
        overwrite: false,
      );
    });

    log(LogLevel.info, 'PendingTransaction_commit result: $commitResult');

    final errorMsg = tx.errorString;
    if (errorMsg != '' && errorMsg != 'Schema expected string') {
      log(LogLevel.error, 'PendingTransaction_commit error: $errorMsg');
      throw FormatException(errorMsg);
    }

    await refresh();
    await loadTxHistory();
  }

  // ----- Monero-specific extras -----

  Future<String> resolveOpenAlias(String address) async {
    const dnssecValid = true;

    log(LogLevel.info, 'Calling WalletManager_resolveOpenAlias with parameters:');
    log(LogLevel.info, '  address: $address');
    log(LogLevel.info, '  dnssecValid: $dnssecValid');

    final wmFfiAddr = _w2WalletManager.ffiAddress();

    final resolved = await Isolate.run(
      // ignore: deprecated_member_use
      () => monero.WalletManager_resolveOpenAlias(
        Pointer.fromAddress(wmFfiAddr),
        address: address,
        dnssecValid: dnssecValid,
      ),
    );

    log(LogLevel.info, 'WalletManager_resolveOpenAlias result: $resolved');
    return resolved;
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
    const getAll = false;

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
        if (connectionUseTor) {
          await TorService.sharedInstance.waitUntilConnected();
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

  // ----- Hooks -----

  @override
  Future<void> load() async {
    if (!isLoaded) return;
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
