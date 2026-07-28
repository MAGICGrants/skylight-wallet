import 'dart:io';

import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:skylight_wallet/consts.dart' as consts;

class PeriodicTasks {
  static const txNotifier = 'txNotifier';
}

/// Max wall-clock we let a background run scan before returning, leaving margin
/// under Android's ~10-minute WorkManager budget to persist + notify.
const _backgroundSyncBudget = Duration(minutes: 9);

/// WorkManager's minimum periodic interval.
const _minSyncIntervalMinutes = 15;

Future<bool> runTxNotifier() async {
  final wallet = WalletModel();

  if (!await wallet.hasExistingWallet()) {
    return true;
  }

  // Load the connection first so the correct-mode wallet file is opened.
  await wallet.loadPersistedConnection();
  await wallet.openExisting();

  final backgroundSync =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
      false;

  // A full-node scan is heavy and only runs when Background Sync is on; an LWS
  // wallet always syncs (server-side, cheap).
  if (wallet.connectionType == 'node' && !backgroundSync) {
    return true;
  }

  if (wallet.usingTor) {
    await TorService.sharedInstance.start();
    await TorService.sharedInstance.waitUntilConnected().timeout(
      Duration(minutes: 2),
      onTimeout: () => log(LogLevel.warn, '[Background sync] Tor connection timed out'),
    );
  }

  if (wallet.connectionAddress.isEmpty) {
    return true;
  }

  // Kick the daemon connection (starts the scan thread + the wallet's timers).
  try {
    await wallet.connectToDaemon();
  } catch (e) {
    log(LogLevel.warn, '[Background sync] connect failed: $e');
  }

  // Keep the isolate alive so the on-device scan keeps advancing, up to the OS
  // budget. The wallet's own timers drive the refresh + checkpoint; we just
  // wait (and bail early once it's synced).
  final deadline = DateTime.now().add(_backgroundSyncBudget);
  while (DateTime.now().isBefore(deadline)) {
    if (wallet.isConnected && wallet.isSynced) break;
    await Future.delayed(const Duration(seconds: 5));
  }

  final notify =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;

  try {
    await wallet.loadTxHistory(persistCount: false);
  } catch (e) {
    log(LogLevel.warn, '[Background sync] loadTxHistory failed: $e');
  }

  await _notifyNewTxs(wallet, notify: notify);

  return true;
}

Future<void> _notifyNewTxs(WalletModel wallet, {required bool notify}) async {
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

  // A node sync is heavy, so gate it on charging + WiFi; notifications are light.
  final constraints = backgroundSync
      ? Constraints(networkType: NetworkType.unmetered, requiresCharging: true)
      : Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true);

  await Workmanager().registerPeriodicTask(
    PeriodicTasks.txNotifier,
    "Background sync",
    frequency: Duration(
      minutes: minutes < _minSyncIntervalMinutes ? _minSyncIntervalMinutes : minutes,
    ),
    constraints: constraints,
  );
}

Future<void> registerPeriodicTasks() async {
  if (!Platform.isAndroid) {
    return;
  }

  Workmanager().initialize(_callbackDispatcher);
  await applyBackgroundTaskRegistration();
}
