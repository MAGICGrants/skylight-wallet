import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/monero_wallet_adapter.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';

import 'package:wallet_infra/wallet_infra.dart' as wcore;
import 'package:wallet_domain/wallet_domain.dart'
    show
        WalletAppConfig,
        WalletManager,
        CryptoWallet,
        SeedSource,
        RestorePoint,
        baseUnitsToDecimalString;
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;
import 'package:wallet_openalias/wallet_openalias.dart' show resolveOpenAlias;

const _moneroDecimals = 12;

bool get _isMobile => Platform.isAndroid || Platform.isIOS;

bool _walletCoreInstalled = false;

/// Installs wallet-core's app config + injectable seams. Idempotent: the main
/// isolate calls it from main(), and each background isolate calls it too (a
/// fresh isolate does not inherit the main one's statics).
void installWalletCore() {
  if (_walletCoreInstalled) return;
  _walletCoreInstalled = true;

  WalletAppConfig.install(WalletAppConfig.skylight);
  CryptoWallet.aliasResolver = resolveOpenAlias;

  wcore.WalletLog.sink = const _SkylightLogSink();
  wcore.WalletLog.isVerbose = () async =>
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
      false;

  CryptoWallet.incomingTxNotifier = (tx, _) {
    final amount =
        double.tryParse(baseUnitsToDecimalString(tx.amountBaseUnits, _moneroDecimals)) ?? 0;
    if (!_isMobile) {
      // Desktop has no notifications toggle (it's Android/iOS-only), so it always
      // shows an incoming-tx notification.
      NotificationService().showIncomingTxNotification(amount);
      return;
    }
    // Mobile respects the toggle. notifyNewIncomingTxs still records the tx as
    // seen whether or not this fires, so turning it on later does not replay a
    // backlog.
    SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled).then((on) {
      if (on ?? false) NotificationService().showIncomingTxNotification(amount);
    });
  };
}

/// Opens the XMR wallet inside a background isolate (WorkManager / foreground
/// service), or returns null when there is no wallet or this window should not
/// sync it. The connection is loaded first so the correct-mode file opens and
/// the node/Tor gates can be checked before the expensive open.
///
/// [allowTor]/[allowNode] describe what the scheduling window can accommodate;
/// [requireBackgroundSyncForNode] additionally skips a node wallet unless the
/// user turned Background Sync on (a node scan is heavy — the periodic task
/// sets it, the foreground service does not). The manager is kept alive for the
/// isolate's lifetime by the wallet's listener back to it.
Future<AppWallet?> openBackgroundWallet({
  bool allowTor = true,
  bool allowNode = true,
  bool requireBackgroundSyncForNode = false,
}) async {
  installWalletCore();
  final manager = WalletManager(coins: () => [MoneroWallet()]);
  if (!await manager.hasAnyExistingWallet()) return null;

  // Loads the persisted connection for each coin without opening files.
  await manager.loadCachedDisplayState();
  final wallet = manager.getWallet('XMR') as MoneroWallet;
  if (!await _shouldBackgroundSync(
    connectionType: wallet.connectionType,
    usingTor: wallet.usingTor,
    allowTor: allowTor,
    allowNode: allowNode,
    requireBackgroundSyncForNode: requireBackgroundSyncForNode,
  )) {
    return null;
  }

  await manager.openAll();
  return MoneroWalletAdapter(wallet);
}

Future<bool> _shouldBackgroundSync({
  required String connectionType,
  required bool usingTor,
  required bool allowTor,
  required bool allowNode,
  required bool requireBackgroundSyncForNode,
}) async {
  if (!allowNode && connectionType == 'node') return false;
  if (!allowTor && usingTor) return false;
  if (requireBackgroundSyncForNode && connectionType == 'node') {
    final on =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
        false;
    if (!on) return false;
  }
  return true;
}

/// The wallet-core [WalletManager] provider.
ChangeNotifierProvider<WalletManager> walletManagerProvider() =>
    ChangeNotifierProvider(create: (_) => WalletManager(coins: () => [MoneroWallet()]));

/// Startup for the wallet-core stack: whether a wallet exists (for the initial
/// route) and, on mobile, opening + starting its sync.
Future<bool> startupWalletManager(BuildContext context) =>
    _loadExistingWalletManager(Provider.of<WalletManager>(context, listen: false));

Future<bool> _loadExistingWalletManager(WalletManager manager) async {
  if (await manager.hasAnyExistingWallet()) {
    if (_isMobile) {
      await manager.loadCachedDisplayState();
      manager.openWalletFilesAndSync();
    }
    return true;
  }
  return false;
}

final _adapters = Expando<MoneroWalletAdapter>('appWalletAdapter');

/// The neutral [AppWallet] for the XMR wallet. The adapter is cached per wallet
/// so repeated lookups don't stack duplicate listeners.
AppWallet appWalletOf(BuildContext context, {bool listen = false}) {
  final manager = Provider.of<WalletManager>(context, listen: listen);
  final wallet = manager.getWallet('XMR') as MoneroWallet;
  return _adapters[wallet] ??= MoneroWalletAdapter(
    wallet,
    readStoredSeed: () async {
      final stored = await manager.loadStoredSeed();
      if (stored == null) return null;
      return (mnemonic: stored.seed.mnemonic, format: stored.seed.format.name);
    },
  );
}

/// Sets the wallet-encryption password (desktop-entered). Mobile mints a random
/// one at restore/create time instead.
void setWalletPassword(BuildContext context, String password) {
  Provider.of<WalletManager>(context, listen: false).setWalletPassword(password);
}

/// Restores the wallet from a mnemonic at [restoreHeight], then opens + syncs.
/// Throws Exception('Invalid mnemonic.') on an unrecognized seed.
Future<void> restoreWallet(
  BuildContext context, {
  required String mnemonic,
  required int restoreHeight,
}) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  final seed = SeedSource.detect(mnemonic);
  if (seed == null) throw Exception('Invalid mnemonic.');
  if (!manager.hasPassword) manager.useGeneratedPassword();
  await manager.restoreAll(seed: seed, from: RestorePoint.height(restoreHeight));
  manager.syncInBackground();
}

/// Creates a brand-new wallet, then opens + syncs. Returns its seed words and
/// restore height (for the seed-backup screen and the connection step).
Future<(String seed, int restoreHeight)> createWallet(BuildContext context) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  if (!manager.hasPassword) manager.useGeneratedPassword();
  final generated = manager.generateSeed();
  await manager.restoreAll(seed: generated.seed, from: RestorePoint.date(generated.restoreDate));
  manager.syncInBackground();
  final height = await manager.getWallet('XMR')!.getRestoreHeight();
  return (generated.seed.mnemonic, height);
}

/// Opens an already-existing wallet (used by the welcome safety-net). Returns
/// false when there is none. Mobile only — desktop unlocks with a password.
Future<bool> openExistingWallet(BuildContext context) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  if (!await manager.hasAnyExistingWallet()) return false;
  manager.openWalletFilesAndSync();
  return true;
}

/// Opens the wallet with a desktop-entered password, then syncs. Throws on a
/// wrong password (the unlock screen shows the error).
Future<void> unlockWithPassword(BuildContext context, String password) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  await manager.openAll(password: password);
  manager.syncInBackground();
}

/// Deletes the wallet and everything derived from it.
Future<void> deleteWallet(BuildContext context) async {
  // TODO(wallet-core): pass skylight's own pref keys (contacts, pending tx,
  // notification state) once the delete path is validated on device.
  await Provider.of<WalletManager>(context, listen: false).deleteAll();
}

/// Rebuilds the wallet if the server kind (LWS↔node) changed, then resyncs.
void applyConnectionChange(BuildContext context) {
  unawaited(Provider.of<WalletManager>(context, listen: false).applyConnectionChange('XMR'));
}

/// Routes wallet-core log lines into skylight's logger.
class _SkylightLogSink extends wcore.LogSink {
  const _SkylightLogSink();

  @override
  Future<void> write(wcore.LogLevel level, String line) => log(switch (level) {
    wcore.LogLevel.info => LogLevel.info,
    wcore.LogLevel.warn => LogLevel.warn,
    wcore.LogLevel.error => LogLevel.error,
  }, line);
}
