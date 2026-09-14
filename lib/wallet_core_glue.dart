import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/monero_wallet_adapter.dart';
import 'package:skylight_wallet/widgets/tx_details.dart' show TxDetailsDialog;
import 'package:skylight_wallet/periodic_tasks.dart' show backgroundDispatcher;
import 'package:skylight_wallet/services/foreground_sync_service.dart' show foregroundSyncCallback;
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';

import 'package:wallet_infra/wallet_infra.dart' as wcore;
import 'package:wallet_background/wallet_background.dart' show BackgroundSync;
import 'package:wallet_fiat/wallet_fiat.dart' show FiatRates;
import 'package:wallet_domain/wallet_domain.dart'
    show
        WalletAppConfig,
        WalletManager,
        CryptoWallet,
        SeedSource,
        RestorePoint,
        TxDetails,
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

  wcore.NotificationService.windowsAppName = 'Skylight Wallet';
  wcore.NotificationService.windowsAppUserModelId = 'org.magicgrants.skylight';
  wcore.NotificationService.windowsGuid = '6dcf17a9-fb5f-4f47-b0b9-6d655e90adbf';

  BackgroundSync.install(
    coins: () => [MoneroWallet()],
    workmanagerCallback: backgroundDispatcher,
    foregroundCallback: foregroundSyncCallback,
    ensureTorConnected: _ensureTorConnected,
    iosBundleId: 'org.magicgrants.skylightwallet',
    foregroundTitle: 'Skylight Wallet',
  );

  FiatRates.install(getTorProxy: TorSettingsService.sharedInstance.getProxy);

  // The whole logger lives in wallet-core now (D25): console + file sinks fan out
  // from one installed sink; the file sink is verbose-gated internally.
  wcore.WalletLog.sink = wcore.CompositeLogSink([
    const wcore.DebugPrintLogSink(),
    wcore.FileLogSink(),
  ]);
  wcore.WalletLog.isVerbose = () async =>
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
      false;

  CryptoWallet.incomingTxNotifier = (tx, _) {
    final amount =
        double.tryParse(baseUnitsToDecimalString(tx.amountBaseUnits, _moneroDecimals)) ?? 0;
    void show() => NotificationService().showIncomingTxNotification(
      title: 'Incoming transaction',
      body: 'You received $amount XMR',
    );
    if (!_isMobile) {
      // Desktop has no notifications toggle (it's Android/iOS-only), so it always
      // shows an incoming-tx notification.
      show();
      return;
    }
    // Mobile respects the toggle. notifyNewIncomingTxs still records the tx as
    // seen whether or not this fires, so turning it on later does not replay a
    // backlog.
    SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled).then((on) {
      if (on ?? false) show();
    });
  };
}

/// Brings skylight's Tor up and reports whether it connected — the seam
/// `wallet_background` uses so a background isolate starts the *same* Tor the
/// wallet connects through. (Background open + the node/Tor gate now live inside
/// `wallet_background`.)
Future<bool> _ensureTorConnected() async {
  await TorService.sharedInstance.start();
  return TorService.sharedInstance.waitUntilConnected(timeout: const Duration(minutes: 2));
}

/// The wallet-core [WalletManager] provider.
ChangeNotifierProvider<WalletManager> walletManagerProvider() =>
    ChangeNotifierProvider(create: (_) => WalletManager(coins: () => [MoneroWallet()]));

/// Attaches the [WalletManager] to the fiat model so it fetches rates for the
/// active coins (XMR). Call once at startup; the model stays attached, so every
/// `FiatRateModel.startService()` afterwards needs no manager argument.
void attachFiatWalletManager(BuildContext context) {
  Provider.of<FiatRateModel>(
    context,
    listen: false,
  ).attachWalletManager(Provider.of<WalletManager>(context, listen: false));
}

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

/// The engine [CryptoWallet] for XMR, for display-only widgets (e.g. the shared
/// tx-activity row) that need the wallet's decimals/symbols. Keeps the
/// [WalletManager] access in the glue layer, not the screen.
CryptoWallet? xmrWallet(BuildContext context) =>
    Provider.of<WalletManager>(context, listen: false).getWallet('XMR');

/// Shows the shared tx-details sheet (`wallet_ui`, D24) for [tx] from the tx
/// list. The activity list now renders the engine's wallet_domain TxDetails
/// directly, so no neutral-to-engine bridge is needed.
void showTxDetailsDialog(BuildContext context, TxDetails tx) {
  final wallet = Provider.of<WalletManager>(context, listen: false).getWallet('XMR')!;
  TxDetailsDialog.show(context, wallet, tx);
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

/// Generates a new seed IN MEMORY — no wallet file is written yet. Persist it
/// with [commitGeneratedWallet] once the user confirms their backup.
({SeedSource seed, DateTime restoreDate}) generateWalletSeed(BuildContext context) {
  final manager = Provider.of<WalletManager>(context, listen: false);
  if (!manager.hasPassword) manager.useGeneratedPassword();
  return manager.generateSeed();
}

/// Writes the generated wallet to disk, then opens + syncs. Returns its restore
/// height (for the LWS-details step). Call when the user taps Continue.
Future<int> commitGeneratedWallet(
  BuildContext context, {
  required SeedSource seed,
  required DateTime restoreDate,
}) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  await manager.restoreAll(seed: seed, from: RestorePoint.date(restoreDate));
  manager.syncInBackground();
  return manager.getWallet('XMR')!.getRestoreHeight();
}

/// Arms the app-lock re-lock when the app goes to the background; see
/// [WalletManager.armAppLockRelock], which both apps share so the behaviour
/// cannot drift. Wrapped here only because Skylight reaches wallet-core through
/// this layer rather than from screens.
Future<bool> armAppLockRelock(BuildContext context) =>
    Provider.of<WalletManager>(context, listen: false).armAppLockRelock();

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
