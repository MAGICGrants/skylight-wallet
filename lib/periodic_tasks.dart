import 'dart:io';

import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/wallets/crypto_wallet.dart';
import 'package:spice_wallet/wallets/wallet_manager.dart';
import 'package:workmanager/workmanager.dart';
import 'package:spice_wallet/consts.dart' as consts;

class PeriodicTasks {
  static const txNotifier = 'txNotifier';
}

/// Max wall-clock we let a background run scan before returning, leaving margin
/// under Android's ~10-minute WorkManager budget to persist + notify.
const _backgroundSyncBudget = Duration(minutes: 9);

Future<bool> runTxNotifier() async {
  final walletManager = WalletManager();

  if (!await walletManager.hasAnyExistingWallet()) {
    return true;
  }

  await walletManager.openAll();

  final wallets = walletManager.activeWallets;
  if (wallets.isEmpty) return true;

  for (final w in wallets) {
    await w.loadPersistedConnection();
  }

  if (wallets.any((w) => w.usingTor)) {
    await TorService.sharedInstance.start();
    await TorService.sharedInstance.waitUntilConnected().timeout(
      Duration(minutes: 2),
      onTimeout: () => log(LogLevel.warn, '[Background sync] Tor connection timed out'),
    );
  }

  // Kick each wallet's daemon connection (starts the scan thread).
  await Future.wait(
    wallets.map((w) async {
      if (w.connectionAddress.isEmpty) return;
      try {
        await w.connectToDaemon();
      } catch (e) {
        log(LogLevel.warn, '[Background sync] connect failed: $e', coin: w.coinSymbol);
      }
    }),
  );

  // Keep the isolate alive so the on-device scan keeps advancing, up to the OS
  // budget. The wallets' own timers drive the refresh + checkpoint; we just wait
  // (and bail early once everything's synced).
  final deadline = DateTime.now().add(_backgroundSyncBudget);
  while (DateTime.now().isBefore(deadline)) {
    final allDone = wallets.every(
      (w) => w.connectionAddress.isEmpty || (w.isConnected && w.isSynced),
    );
    if (allDone) break;
    await Future.delayed(const Duration(seconds: 5));
  }

  final notify =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;

  for (final w in wallets) {
    if (w.connectionAddress.isEmpty) continue;
    try {
      await w.loadTxHistory(persistCount: false);
    } catch (e) {
      log(LogLevel.warn, '[Background sync] loadTxHistory failed: $e', coin: w.coinSymbol);
    }
    await _notifyNewTxsForWallet(w, notify: notify);
  }

  return true;
}

Future<void> _notifyNewTxsForWallet(CryptoWallet wallet, {required bool notify}) async {
  if (wallet.connectionAddress.isEmpty) return;

  final persistedCount = await wallet.getPersistedTxHistoryCount();
  final currentCount = wallet.txHistory.length;
  final countOfNewTxs = currentCount - persistedCount;

  if (countOfNewTxs > 0 && currentCount != 0) {
    // Only surface a notification when notifications are on; either way advance
    // the baseline count so we don't re-notify (or flood) next run.
    if (notify) {
      for (int i = 0; i < countOfNewTxs; i++) {
        final tx = wallet.txHistory[i];
        if (tx.direction == consts.txDirectionIncoming) {
          NotificationService().showIncomingTxNotification(tx.amount);
        }
      }
    }

    await wallet.persistTxHistoryCount();
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

/// WorkManager's minimum periodic interval.
const _minSyncIntervalMinutes = 15;

/// (Re)registers the background task if background sync or notifications is on,
/// otherwise cancels it. Notifications need the task to run to detect new txs,
/// so either flag keeps it scheduled; the interval comes from the background-
/// sync setting. Android only.
Future<void> applyBackgroundTaskRegistration() async {
  if (!Platform.isAndroid) return;

  final backgroundSync =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
      false;
  final notifications =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;

  await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
  if (!backgroundSync && !notifications) return;

  final minutes =
      await SharedPreferencesService.get<int>(
        SharedPreferencesKeys.backgroundSyncIntervalMinutes,
      ) ??
      _minSyncIntervalMinutes;

  await Workmanager().registerPeriodicTask(
    PeriodicTasks.txNotifier,
    "Background sync",
    frequency: Duration(
      minutes: minutes < _minSyncIntervalMinutes ? _minSyncIntervalMinutes : minutes,
    ),
    constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true),
  );
}

Future<void> registerPeriodicTasks() async {
  if (!Platform.isAndroid) {
    return;
  }

  Workmanager().initialize(_callbackDispatcher);
  await applyBackgroundTaskRegistration();
}
