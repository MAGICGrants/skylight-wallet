import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/monero_wallet_adapter.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
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

/// Phase 6 flag: route the wallet layer through wallet-core.
const useSharedWalletCore = bool.fromEnvironment('useSharedWalletCore');

const _moneroDecimals = 12;

bool get _isMobile => Platform.isAndroid || Platform.isIOS;

/// Installs wallet-core's app config + injectable seams. Call once from main().
void installWalletCore() {
  WalletAppConfig.install(WalletAppConfig.skylight);
  CryptoWallet.aliasResolver = resolveOpenAlias;

  wcore.WalletLog.sink = const _SkylightLogSink();
  wcore.WalletLog.isVerbose = () async =>
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ?? false;

  CryptoWallet.incomingTxNotifier = (tx, _) {
    final amount = double.tryParse(baseUnitsToDecimalString(tx.amountBaseUnits, _moneroDecimals)) ?? 0;
    NotificationService().showIncomingTxNotification(amount);
  };
}

/// WalletManager provider, gated. Coexists with WalletModel during migration.
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

/// The neutral [AppWallet] for the active stack: the shared-core adapter under
/// the flag, else the legacy [WalletModel]. The adapter is cached per wallet so
/// repeated lookups don't stack duplicate listeners.
AppWallet appWalletOf(BuildContext context, {bool listen = false}) {
  if (!useSharedWalletCore) {
    return Provider.of<WalletModel>(context, listen: listen);
  }
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
  if (useSharedWalletCore) {
    Provider.of<WalletManager>(context, listen: false).setWalletPassword(password);
  } else {
    Provider.of<WalletModel>(context, listen: false).setWalletPassword(password);
  }
}

/// Restores the wallet from a mnemonic at [restoreHeight], then opens + syncs.
/// Throws Exception('Invalid mnemonic.') on an unrecognized seed.
Future<void> restoreWallet(
  BuildContext context, {
  required String mnemonic,
  required int restoreHeight,
}) async {
  if (useSharedWalletCore) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    final seed = SeedSource.detect(mnemonic);
    if (seed == null) throw Exception('Invalid mnemonic.');
    if (!manager.hasPassword) manager.useGeneratedPassword();
    await manager.restoreAll(seed: seed, from: RestorePoint.height(restoreHeight));
    manager.syncInBackground();
  } else {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    await wallet.restoreFromMnemonic(mnemonic, restoreHeight);
    wallet.load();
  }
}

/// Creates a brand-new wallet, then opens + syncs. Returns its seed words and
/// restore height (for the seed-backup screen and the connection step).
Future<(String seed, int restoreHeight)> createWallet(BuildContext context) async {
  if (useSharedWalletCore) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (!manager.hasPassword) manager.useGeneratedPassword();
    final generated = manager.generateSeed();
    await manager.restoreAll(seed: generated.seed, from: RestorePoint.date(generated.restoreDate));
    manager.syncInBackground();
    final height = await manager.getWallet('XMR')!.getRestoreHeight();
    return (generated.seed.mnemonic, height);
  } else {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final result = await wallet.create();
    wallet.load();
    return result;
  }
}

/// Opens an already-existing wallet (used by the welcome safety-net). Returns
/// false when there is none. Mobile only — desktop unlocks with a password.
Future<bool> openExistingWallet(BuildContext context) async {
  if (useSharedWalletCore) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (!await manager.hasAnyExistingWallet()) return false;
    manager.openWalletFilesAndSync();
    return true;
  }
  final wallet = Provider.of<WalletModel>(context, listen: false);
  if (!await wallet.hasExistingWallet()) return false;
  await wallet.loadPersistedConnection();
  await wallet.openExisting();
  return true;
}

/// Opens the wallet with a desktop-entered password, then syncs. Throws on a
/// wrong password (the unlock screen shows the error).
Future<void> unlockWithPassword(BuildContext context, String password) async {
  if (useSharedWalletCore) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    await manager.openAll(password: password);
    manager.syncInBackground();
  } else {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    await wallet.loadPersistedConnection();
    await wallet.openExisting(desktopWalletPassword: password);
    wallet.load();
  }
}

/// Deletes the wallet and everything derived from it.
Future<void> deleteWallet(BuildContext context) async {
  if (useSharedWalletCore) {
    // TODO(wallet-core): pass skylight's own pref keys (contacts, pending tx,
    // notification state) once the flag-on delete path is validated on device.
    await Provider.of<WalletManager>(context, listen: false).deleteAll();
  } else {
    await Provider.of<WalletModel>(context, listen: false).delete();
  }
}

/// Rebuilds the wallet if the server kind (LWS↔node) changed, then resyncs.
void applyConnectionChange(BuildContext context) {
  if (useSharedWalletCore) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    unawaited(manager.reopenWallet('XMR').then((_) => manager.syncInBackground()));
  } else {
    Provider.of<WalletModel>(context, listen: false).applyConnectionChange();
  }
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
