import 'dart:io';
import 'dart:ui' show Color;

import 'package:provider/provider.dart';

import 'package:spice_wallet/periodic_tasks.dart' show backgroundDispatcher;
import 'package:spice_wallet/services/foreground_sync_service.dart' show foregroundSyncCallback;
import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';

import 'package:wallet_infra/wallet_infra.dart' as wcore;
import 'package:wallet_background/wallet_background.dart' show BackgroundSync, NotificationIcon;
import 'package:wallet_fiat/wallet_fiat.dart' show FiatRates;
import 'package:wallet_domain/wallet_domain.dart'
    show WalletAppConfig, WalletManager, CryptoWallet, baseUnitsToDecimalString;
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;
import 'package:wallet_bitcoin/wallet_bitcoin.dart' show BitcoinWallet, BitcoinTestnetWallet;
import 'package:wallet_ethereum/wallet_ethereum.dart'
    show EthereumWallet, EthereumSepoliaWallet, DaiWallet, DaiSepoliaWallet;
import 'package:wallet_openalias/wallet_openalias.dart' show resolveOpenAlias;

bool get _isMobile => Platform.isAndroid || Platform.isIOS;

/// baseUnitDecimals per coin, for formatting incoming-tx notification amounts.
/// The notifier only receives a `coinSymbol`, not the wallet, so the magnitudes
/// are listed here rather than read off each `CryptoWallet`.
const _baseUnitDecimals = <String, int>{
  'XMR': 12,
  'BTC': 8,
  'TBTC': 8,
  'ETH': 18,
  'SETH': 18,
  'DAI': 18,
  'SDAI': 18,
};

/// The coins spice registers. A fresh list each call — [WalletManager] and each
/// background isolate own their own instances.
List<CryptoWallet> buildCoins() => [
  MoneroWallet(),
  BitcoinWallet(),
  BitcoinTestnetWallet(),
  EthereumWallet(),
  EthereumSepoliaWallet(),
  DaiWallet(),
  DaiSepoliaWallet(),
];

bool _walletCoreInstalled = false;

/// Installs wallet-core's app config + injectable seams. Idempotent: main()
/// calls it, and each background isolate calls it too (a fresh isolate does not
/// inherit the main one's statics).
void installWalletCore() {
  if (_walletCoreInstalled) return;
  _walletCoreInstalled = true;

  WalletAppConfig.install(WalletAppConfig.spice);
  CryptoWallet.aliasResolver = resolveOpenAlias;

  wcore.NotificationService.windowsAppName = 'Spice Wallet';
  wcore.NotificationService.windowsAppUserModelId = 'org.magicgrants.spice';
  wcore.NotificationService.windowsGuid = '6dcf17a9-fb5f-4f47-b0b9-6d655e90adbf';
  // Same status-bar mark as the continuous-sync foreground-service notification.
  wcore.NotificationService.androidSmallIcon = 'ic_stat_spice';

  BackgroundSync.install(
    coins: buildCoins,
    workmanagerCallback: backgroundDispatcher,
    foregroundCallback: foregroundSyncCallback,
    ensureTorConnected: _ensureTorConnected,
    iosBundleId: 'org.magicgrants.spicewallet',
    foregroundTitle: 'Spice Wallet',
    // Spice's spiral mark (white silhouette) as the sync notification's small
    // icon, tinted cinnamon; the res + manifest meta-data live in android/.
    foregroundIcon: const NotificationIcon(
      metaDataName: 'org.magicgrants.spicewallet.notification_icon',
      backgroundColor: Color(0xFFA0451C),
    ),
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

  CryptoWallet.incomingTxNotifier = (tx, coinSymbol) {
    final decimals = _baseUnitDecimals[coinSymbol] ?? 0;
    final amount = double.tryParse(baseUnitsToDecimalString(tx.amountBaseUnits, decimals)) ?? 0;
    void show() => NotificationService().showIncomingTxNotification(
      title: 'Incoming transaction',
      body: 'You received $amount $coinSymbol',
    );
    if (!_isMobile) {
      // Desktop has no notifications toggle (Android/iOS-only), so it always
      // shows an incoming-tx notification.
      show();
      return;
    }
    // Mobile respects the toggle.
    SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled).then((on) {
      if (on ?? false) show();
    });
  };
}

/// Brings spice's Tor up and reports whether it connected — the seam
/// `wallet_background` uses so a background isolate starts the *same* Tor the
/// wallet connects through.
Future<bool> _ensureTorConnected() async {
  await TorService.sharedInstance.start();
  await TorService.sharedInstance.waitUntilConnected().timeout(
    const Duration(minutes: 2),
    onTimeout: () {},
  );
  return TorService.sharedInstance.status == TorConnectionStatus.connected;
}

/// The wallet-core [WalletManager] provider.
ChangeNotifierProvider<WalletManager> walletManagerProvider() =>
    ChangeNotifierProvider(create: (_) => WalletManager(coins: buildCoins));
