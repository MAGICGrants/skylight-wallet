import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/models/app_wallet.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/monero_wallet_adapter.dart';
import 'package:skylight_wallet/widgets/tx_details.dart' show TxDetailsDialog;
import 'package:skylight_wallet/periodic_tasks.dart' show backgroundDispatcher;
import 'package:skylight_wallet/services/foreground_sync_service.dart'
    show foregroundSyncCallback, stopSyncAndDeleteWallets, restartForegroundSyncIfRunning;
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';

import 'package:wallet_infra/wallet_infra.dart' as wcore;
import 'package:wallet_background/wallet_background.dart' show BackgroundSync, NotificationIcon;
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
import 'package:wallet_backup_platform/wallet_backup_platform.dart'
    show MetadataBackupConfig, MetadataBackupSetup;
import 'package:wallet_fhse/security_keys_ui.dart' show SecurityKeysUi, SecurityKeysUiConfig;
import 'package:wallet_fhse/wallet_fhse.dart' show FhseNative, FhseWalletGuard;
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet, closeOrphanedMoneroWallets;
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
  // Android: native Monero wallets an app isolate left open when it was
  // destroyed (swiped away) are closed by whoever takes over.
  WalletManager.closeOrphanedWallets = closeOrphanedMoneroWallets;

  // Where the wallet password is generated (mobile and macOS) it is FHSE's
  // root, derived from the seed, and security keys can later take it out of
  // the keystore (Settings > Advanced Security). Installed in every isolate, so
  // background runs know when the password is behind keys and check in with
  // the view key instead. Where the user types it (Linux, Windows), a new
  // wallet gets the same root and the typed password unlocks it, together with
  // a key once keys are on; only where FHSE's library loads, so a computer
  // without it keeps the typed password as the wallet password.
  if (wcore.WalletSecrets.holdsWalletPassword || FhseNative.isAvailable) {
    WalletManager.passwordGuard = const FhseWalletGuard();
  }

  wcore.NotificationService.windowsAppName = 'Skylight Wallet';
  wcore.NotificationService.windowsAppUserModelId = 'org.magicgrants.skylight';
  wcore.NotificationService.windowsGuid = '6dcf17a9-fb5f-4f47-b0b9-6d655e90adbf';
  // Same status-bar mark as the continuous-sync foreground-service notification.
  wcore.NotificationService.androidSmallIcon = 'ic_stat_skylight';

  BackgroundSync.install(
    coins: () => [MoneroWallet()],
    workmanagerCallback: backgroundDispatcher,
    foregroundCallback: foregroundSyncCallback,
    ensureTorConnected: _ensureTorConnected,
    iosBundleId: 'org.magicgrants.skylightwallet',
    foregroundTitle: 'Skylight Wallet',
    foregroundIcon: const NotificationIcon(
      metaDataName: 'org.magicgrants.skylightwallet.notification_icon',
      backgroundColor: Color(0xFFF5681C),
    ),
  );

  FiatRates.install(getTorProxy: TorSettingsService.sharedInstance.getProxy);

  // The whole logger lives in wallet-core now: console + file sinks fan out
  // from one installed sink; the file sink writes only with logging on.
  wcore.WalletLog.sink = wcore.CompositeLogSink([
    const wcore.DebugPrintLogSink(),
    wcore.FileLogSink(),
  ]);
  wcore.WalletLog.isLoggingOn = () async =>
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.loggingEnabled) ?? false;

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
  final settings = TorSettingsService.sharedInstance;
  await settings.ensureLoaded();
  if (settings.torMode != TorMode.builtIn) {
    // External: the proxy is the user's, and `getProxy` fails closed if it is
    // not usable. Disabled: there is no Tor to report.
    return settings.torMode == TorMode.external;
  }

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
    // App Lock is always on, so nothing is decrypted before the user gets past
    // it: the unlock screen opens the wallet (reopenAfterAppLock). Linux and
    // Windows wait for the typed password the same way.
    if (wcore.WalletSecrets.holdsWalletPassword) await manager.loadCachedDisplayState();
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

/// Shows the shared tx-details sheet (`wallet_ui`) for [tx] from the tx
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
  await manager.restoreAll(seed: seed, from: RestorePoint.date(restoreDate), freshSeed: true);
  manager.syncInBackground();
  return manager.getWallet('XMR')!.getRestoreHeight();
}

/// After a sync or notifications toggle changes: Monero's view-only background
/// copy and the view-only material every background run uses, set up or
/// removed now rather than at the next launch ([WalletManager.applySyncSettings]).
/// Bound before the caller's awaits.
Future<void> Function() syncSettingsApplier(BuildContext context) =>
    Provider.of<WalletManager>(context, listen: false).applySyncSettings;

/// Where the welcome safety-net sends an install that already has a wallet,
/// or null when there is none: through the same locks as a launch, so the
/// unlock screen (App Lock is always on; the typed password on Linux and
/// Windows), and a security key after it when keys are on.
Future<String?> existingWalletRoute(BuildContext context) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  return await manager.hasAnyExistingWallet() ? '/unlock' : null;
}

/// App Lock on Linux and Windows after a time without use: the wallet stayed
/// open, so the password is only checked again ([WalletManager.checkTypedPassword]).
/// Null when the wallet is not open: [unlockWithPassword] opens it.
Future<bool?> recheckPasswordIfOpen(BuildContext context, String password) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  if (!manager.hasPassword) return null;
  return manager.checkTypedPassword(password);
}

/// Opens the wallet with a desktop-entered password, then syncs. Throws on a
/// wrong password (the unlock screen shows the error).
///
/// Returns true when security keys are on: the password was right, and a key
/// comes next, so the caller shows the security-key unlock instead.
Future<bool> unlockWithPassword(BuildContext context, String password) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  if (!await manager.unlockWithTypedPassword(password)) {
    throw Exception('Incorrect wallet password.');
  }
  if (!manager.hasPassword) return true;
  await manager.openAll();
  manager.syncInBackground();
  return false;
}

/// Deletes the wallet and everything derived from it.
///
/// Through wallet-core's teardown rather than a bare `deleteAll`: the
/// foreground service holds its own wallet2 instance open on these files in its
/// own isolate, and deleting them while it runs leaves it syncing -- and
/// rewriting -- a wallet the user just deleted.
Future<void> deleteWallet(BuildContext context) async {
  // TODO(wallet-core): pass skylight's own pref keys (contacts, pending tx,
  // notification state) once the delete path is validated on device.
  await stopSyncAndDeleteWallets(Provider.of<WalletManager>(context, listen: false));
}

/// Rebuilds the wallet if the server kind (LWS↔node) changed, then resyncs.
void applyConnectionChange(BuildContext context) {
  final manager = Provider.of<WalletManager>(context, listen: false);
  // Restart the foreground service too, so its isolate re-reads the new server.
  unawaited(manager.applyConnectionChange('XMR').then((_) => restartForegroundSyncIfRunning()));
}

// ----- Security keys (FHSE) -----

/// The shared security-key screens (wallet_fhse): Skylight's name, mark and
/// home route, and where they find the wallet manager. UI isolate only.
void installSecurityKeysUi() {
  SecurityKeysUi.install(
    SecurityKeysUiConfig(
      appName: 'Skylight',
      walletManagerOf: (context) => Provider.of<WalletManager>(context, listen: false),
      homeRoute: '/wallet_home',
      logo: (_) => SvgPicture.asset('assets/logo_nobg.svg', width: 44, height: 44),
    ),
  );
}

// ----- Metadata backup -----

/// The metadata backup (wallet_backup): who each payment went to, its
/// transaction key, and the address book, encrypted with the seed. Off until the
/// user turns it on in Settings > Backup; then saved on this device, and to
/// iCloud (iOS) or Android's Auto Backup (Android) only if the user turns that
/// on too. UI isolate only, so a background run never writes a backup file.
/// 25-word seeds have none.
void installMetadataBackup() {
  MetadataBackupSetup.install(
    const MetadataBackupConfig(
      appName: 'Skylight',
      iCloudContainer: 'iCloud.org.magicgrants.skylightwallet',
      exportFileStem: 'skylight-backup',
    ),
  );
}
