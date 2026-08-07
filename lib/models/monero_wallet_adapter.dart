import 'package:flutter/foundation.dart';

import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/wallet_model.dart'
    show TxDetails, TxRecipient, LWSConnectionDetails, ResolvedOpenAlias;

import 'package:wallet_domain/wallet_domain.dart' as domain;
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;

const _moneroDecimals = 12;

/// Presents a wallet-core [MoneroWallet] through skylight's [AppWallet] surface,
/// converting wallet-core types (BigInt amounts, TxDetails, connection details)
/// to skylight's. Re-fires the wrapped wallet's notifications.
class MoneroWalletAdapter extends ChangeNotifier implements AppWallet {
  MoneroWalletAdapter(this._wallet, {StoredSeedReader? readStoredSeed})
    : _readStoredSeed = readStoredSeed {
    _wallet.addListener(notifyListeners);
  }

  final MoneroWallet _wallet;
  final StoredSeedReader? _readStoredSeed;

  @override
  void dispose() {
    _wallet.removeListener(notifyListeners);
    super.dispose();
  }

  static double _toXmr(BigInt units) =>
      double.parse(domain.baseUnitsToDecimalString(units, _moneroDecimals));

  // Connection
  @override
  String get connectionAddress => _wallet.connectionAddress;
  @override
  String get connectionProxyPort => _wallet.connectionProxyPort;
  @override
  bool get connectionUseTor => _wallet.connectionUseTor;
  @override
  bool get connectionUseSsl => _wallet.connectionUseSsl;
  @override
  bool get usingTor => _wallet.usingTor;
  @override
  String get connectionType => _wallet.connectionType;
  @override
  bool get isNodeMode => _wallet.connectionType == 'node';
  @override
  bool get hasAttemptedConnection => _wallet.hasAttemptedConnection;
  @override
  bool get torRequirementBroken => _wallet.torRequirementBroken;

  // Sync
  @override
  bool get isConnected => _wallet.isConnected;
  @override
  bool get isSynced => _wallet.isSynced;
  @override
  int? get syncedHeight => _wallet.syncedHeight;
  @override
  int? get syncBlocksRemaining => _wallet.syncBlocksRemaining;

  // Balances + history
  @override
  double? get unlockedBalance => _wallet.unlockedBalance;
  @override
  double? get totalBalance => _wallet.totalBalance;
  @override
  bool? get serverSupportsSubaddresses => _wallet.serverSupportsSubaddresses;
  @override
  String? getUnusedSubaddress() => _wallet.getUnusedSubaddress();
  @override
  bool? get unusedSubaddressIndexIsSupported => _wallet.unusedSubaddressIndexIsSupported;
  @override
  List<TxDetails> get txHistory => [for (final t in _wallet.txHistory) _toSkylightTx(t)];

  TxDetails _toSkylightTx(domain.TxDetails t) => TxDetails(
    index: t.index,
    direction: t.direction,
    hash: t.hash,
    amount: _toXmr(t.amountBaseUnits),
    fee: _toXmr(t.feeBaseUnits),
    recipients: [for (final r in t.recipients) TxRecipient(r.address, _toXmr(r.amountBaseUnits))],
    accountIndex: t.accountIndex,
    subaddrIndexList: t.subaddrIndexList,
    timestamp: t.timestamp,
    height: t.height,
    confirmations: t.confirmations,
    key: t.key,
  );

  // Addresses
  @override
  String getPrimaryAddress() => _wallet.getPrimaryAddress();
  @override
  String? getReceiveAddress() => _wallet.getReceiveAddress();

  // Lifecycle
  @override
  Future<bool> hasExistingWallet() => _wallet.hasExistingWallet();
  @override
  Future<void> load() => _wallet.load();
  @override
  Future<int> getRestoreHeight() => _wallet.getRestoreHeight();
  @override
  Future<void> pauseSyncAndStore() => _wallet.pauseSyncAndStore();

  // Connection ops
  @override
  Future<LWSConnectionDetails> getPersistedConnection() async {
    final c = await _wallet.getPersistedConnection();
    return LWSConnectionDetails(
      address: c.address,
      proxyPort: c.proxyPort,
      useTor: c.useTor,
      useSsl: c.useSsl,
      connectionType: c.connectionType,
    );
  }

  @override
  void setConnection({
    required String address,
    required String proxyPort,
    required bool useTor,
    required bool useSsl,
    String connectionType = '',
  }) => _wallet.setConnection(
    address: address,
    proxyPort: proxyPort,
    useTor: useTor,
    useSsl: useSsl,
    connectionType: connectionType,
  );

  @override
  Future<void> persistCurrentConnection() => _wallet.persistCurrentConnection();
  @override
  Future<void> loadPersistedConnection() => _wallet.loadPersistedConnection();

  @override
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
    String connectionType = '',
  }) => _wallet.testConnection(
    address: address,
    proxyPort: proxyPort,
    useSsl: useSsl,
    useTor: useTor,
    connectionType: connectionType,
  );

  @override
  Future<void> connectToDaemon() => _wallet.connectToDaemon();
  @override
  void onGlobalTorDisabled() => _wallet.onGlobalTorDisabled();

  // Notifications
  @override
  Future<void> markExistingTxsAsNotified() => _wallet.markExistingTxsAsNotified();
  @override
  Future<void> notifyNewIncomingTxs() => _wallet.notifyNewIncomingTxs();

  // Key export
  @override
  Future<String> readSecretViewKey() => _wallet.readSecretViewKey();
  @override
  Future<String> readSecretSpendKey() => _wallet.readSecretSpendKey();
  @override
  Future<String> readPublicViewKey() => _wallet.readPublicViewKey();
  @override
  Future<String> readPublicSpendKey() => _wallet.readPublicSpendKey();
  @override
  Future<String> readLegacySeed() => _wallet.readLegacySeed();
  @override
  Future<String> readPolyseed() => _wallet.readPolyseed();
  @override
  Future<StoredSeed?> readStoredSeed() async => await _readStoredSeed?.call();

  // Send
  @override
  bool isAddressValid(String address) => _wallet.isAddressValid(address);

  @override
  Future<int?> estimateFee(
    String destinationAddress,
    double amount, {
    int priority = 0,
    String? amountText,
  }) async {
    final fee = await _wallet.estimateFee(
      destinationAddress,
      _toBaseUnits(amount, amountText),
      priority: priority,
    );
    return fee?.toInt();
  }

  @override
  Future<AppPendingTx> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority = 0,
    String? amountText,
  }) async {
    final tx = await _wallet.createTx(
      destinationAddress,
      _toBaseUnits(amount, amountText),
      isSweepAll,
      priority: priority,
    );
    return _CorePendingTx(tx);
  }

  @override
  Future<void> commitTx(AppPendingTx tx, String destinationAddress) =>
      _wallet.commitTx((tx as _CorePendingTx).raw, destinationAddress);

  @override
  Future<ResolvedOpenAlias?> resolveOpenAlias(String alias) async {
    // resolveAlias throws when Tor is down or the input is a raw address;
    // skylight's send flow expects null on any failure.
    try {
      final resolved = await _wallet.resolveAlias(alias);
      if (resolved == null) return null;
      return ResolvedOpenAlias(
        address: resolved.address,
        version: 2,
        recipientName: resolved.recipientName,
      );
    } catch (_) {
      return null;
    }
  }

  // Prefer the exact decimal string; a double loses precision (D4).
  static BigInt _toBaseUnits(double amount, String? amountText) => domain.decimalToBaseUnits(
    amountText ?? amount.toStringAsFixed(_moneroDecimals),
    _moneroDecimals,
  );
}

/// Wraps a wallet-core [domain.PendingTransaction] as the neutral [AppPendingTx].
class _CorePendingTx implements AppPendingTx {
  _CorePendingTx(this.raw);
  final domain.PendingTransaction raw;
  @override
  double get amount => MoneroWalletAdapter._toXmr(raw.amountBaseUnits);
  @override
  double get fee => MoneroWalletAdapter._toXmr(raw.feeBaseUnits);
}
