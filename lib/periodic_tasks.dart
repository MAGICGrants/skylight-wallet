import 'dart:io';

import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:workmanager/workmanager.dart';
import 'package:skylight_wallet/consts.dart' as consts;

class PeriodicTasks {
  static const txNotifier = 'txNotifier';
}

Future<bool> runTxNotifier() async {
  final walletManager = WalletManager();

  if (!await walletManager.hasAnyExistingWallet()) {
    return true;
  }

  await walletManager.openAll();

  final wallets = walletManager.loadedWallets;
  if (wallets.isEmpty) return true;

  for (final w in wallets) {
    await w.loadPersistedConnection();
  }

  if (wallets.any((w) => w.usingTor)) {
    await TorService.sharedInstance.start();
    await TorService.sharedInstance.waitUntilConnected().timeout(
      Duration(minutes: 2),
      onTimeout: () => log(LogLevel.warn, '[TX Notifier] Tor connection timed out'),
    );
  }

  await Future.wait(wallets.map(_prepareWalletForNotifier));

  for (final w in wallets) {
    await _notifyNewTxsForWallet(w);
  }

  return true;
}

Future<void> _prepareWalletForNotifier(CryptoWallet wallet) async {
  if (wallet.connectionAddress.isEmpty) return;
  await wallet.refresh();
  await wallet.connectToDaemon();
  await wallet.loadTxHistory(persistCount: false);

  var iters = 0;
  while (true) {
    if (wallet.isConnected && wallet.isSynced) break;
    await Future.delayed(Duration(seconds: 2));
    iters++;
    if (iters == 20) {
      log(
        LogLevel.warn,
        '[TX Notifier] [${wallet.coinSymbol}] Connection timed out',
      );
      return;
    }
  }
}

Future<void> _notifyNewTxsForWallet(CryptoWallet wallet) async {
  if (wallet.connectionAddress.isEmpty) return;

  final persistedCount = await wallet.getPersistedTxHistoryCount();
  final currentCount = wallet.txHistory.length;
  final countOfNewTxs = currentCount - persistedCount;

  if (countOfNewTxs > 0 && currentCount != 0) {
    log(LogLevel.info, '[TX Notifier] [${wallet.coinSymbol}] Found new transactions');

    for (int i = 0; i < countOfNewTxs; i++) {
      final tx = wallet.txHistory[i];
      if (tx.direction == consts.txDirectionIncoming) {
        log(LogLevel.info, '[TX Notifier] [${wallet.coinSymbol}] Notifying tx $i');
        NotificationService().showIncomingTxNotification(tx.amount);
      } else {
        log(LogLevel.info, '[TX Notifier] [${wallet.coinSymbol}] Skipping outgoing tx');
      }
    }

    await wallet.persistTxHistoryCount();
  } else {
    log(LogLevel.info, '[TX Notifier] [${wallet.coinSymbol}] No new transactions');
  }
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (PeriodicTasks.txNotifier) {
      case PeriodicTasks.txNotifier:
        return runTxNotifier();
    }

    return true;
  });
}

Future<void> registerTxNotifierTaskIfAllowed() async {
  final notificationsEnabled =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;

  if (!notificationsEnabled) {
    return;
  }

  final notificationsAreAllowed = await NotificationService().promptPermission();

  if (!notificationsAreAllowed) {
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
    return;
  }

  await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
  await Workmanager().registerPeriodicTask(
    PeriodicTasks.txNotifier,
    "New transactions check",
    frequency: Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true),
  );
}

Future<void> unregisterPeriodicTasks() async {
  await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
}

Future<void> registerPeriodicTasks() async {
  if (!Platform.isAndroid) {
    return;
  }

  Workmanager().initialize(_callbackDispatcher);
  await registerTxNotifierTaskIfAllowed();
}
