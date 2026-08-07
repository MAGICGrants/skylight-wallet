import 'package:flutter/foundation.dart' show Listenable;

import 'package:skylight_wallet/models/wallet_model.dart'
    show TxDetails, LWSConnectionDetails, ResolvedOpenAlias;

/// A transaction built but not yet broadcast, in display (XMR) units. The
/// concrete wallet keeps the native handle; pass it back to the SAME wallet's
/// [AppWallet.commitTx].
abstract interface class AppPendingTx {
  double get amount;
  double get fee;
}

/// The original mnemonic the user backed up; `format` is a [SeedFormat] name
/// ('polyseed' | 'bip39' | 'moneroLegacy').
typedef StoredSeed = ({String mnemonic, String format});
typedef StoredSeedReader = Future<StoredSeed?> Function();

/// The wallet surface screens use. Both the legacy [WalletModel] and the
/// wallet-core adapter implement it, so a screen reads one type regardless of
/// useSharedWalletCore. Divergent flows (send/restore/create) are handled at
/// their screens, not here.
abstract interface class AppWallet implements Listenable {
  // Connection
  String get connectionAddress;
  String get connectionProxyPort;
  bool get connectionUseTor;
  bool get connectionUseSsl;
  bool get usingTor;
  String get connectionType;
  bool get isNodeMode;
  bool get hasAttemptedConnection;
  bool get torRequirementBroken;

  // Sync
  bool get isConnected;
  bool get isSynced;
  int? get syncedHeight;
  int? get syncBlocksRemaining;

  // Balances + history
  double? get unlockedBalance;
  double? get totalBalance;
  List<TxDetails> get txHistory;
  bool? get serverSupportsSubaddresses;

  // Addresses
  String getPrimaryAddress();
  String? getReceiveAddress();

  // Lifecycle
  Future<bool> hasExistingWallet();
  Future<void> load();
  Future<int> getRestoreHeight();
  Future<void> pauseSyncAndStore();

  // Connection ops
  Future<LWSConnectionDetails> getPersistedConnection();
  void setConnection({
    required String address,
    required String proxyPort,
    required bool useTor,
    required bool useSsl,
    String connectionType,
  });
  Future<void> persistCurrentConnection();
  Future<void> loadPersistedConnection();
  Future<void> testConnection({
    required String address,
    String? proxyPort,
    required bool useSsl,
    required bool useTor,
    String connectionType,
  });
  Future<void> connectToDaemon();
  void onGlobalTorDisabled();

  // Notifications
  Future<void> markExistingTxsAsNotified();
  Future<void> notifyNewIncomingTxs();

  // Key export (secret_keys / lws screens)
  Future<String> readSecretViewKey();
  Future<String> readSecretSpendKey();
  Future<String> readPublicViewKey();
  Future<String> readPublicSpendKey();
  Future<String> readLegacySeed();
  Future<String> readPolyseed();
  /// The original backed-up mnemonic (bip39 shows its own words, not the
  /// derived legacy seed), or null when no seed store is kept.
  Future<StoredSeed?> readStoredSeed();

  // Receive (serverSupportsSubaddresses is declared with the sync getters above)
  String? getUnusedSubaddress();
  bool? get unusedSubaddressIndexIsSupported;

  // Send
  bool isAddressValid(String address);
  /// Estimated network fee in base units (piconero), or null when the backend
  /// can't estimate it (typically insufficient balance for that priority).
  Future<int?> estimateFee(
    String destinationAddress,
    double amount, {
    int priority,
    String? amountText,
  });
  Future<AppPendingTx> createTx(
    String destinationAddress,
    double amount,
    bool isSweepAll, {
    int priority,
    String? amountText,
  });
  Future<void> commitTx(AppPendingTx tx, String destinationAddress);
  Future<ResolvedOpenAlias?> resolveOpenAlias(String alias);
}
