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

Future<bool> runTxNotifier() async {
  print('Running tx notifier');
  final wallet = WalletModel();

  if (!await wallet.hasExistingWallet()) {
    return true;
  }

  await wallet.openExisting();
  await wallet.loadPersistedConnection();

  if (wallet.usingTor) {
    await TorService.sharedInstance.start();
    await TorService.sharedInstance.waitUntilConnected().timeout(
      Duration(minutes: 2),
      onTimeout: () => log(LogLevel.warn, '[TX Notifier] Tor connection timed out'),
    );
  }

  await wallet.refresh();
  await wallet.connectToDaemon();
  await wallet.loadTxHistory(persistCount: false);

  int itersBeforeSynced = 0;

  while (true) {
    if (wallet.isConnected && wallet.isSynced) {
      break;
    }

    await Future.delayed(Duration(seconds: 2));

    itersBeforeSynced++;

    if (itersBeforeSynced == 20) {
      log(LogLevel.warn, '[TX Notifier] Wallet connection timed out');
      return false;
    }
  }

  final persistedTxCount = await wallet.getPersistedTxHistoryCount();
  // FIXME: REMOVE THIS +1 WHEN DONE
  final currentTxCount = wallet.txHistory.length + 1;
  final countOfNewTxs = currentTxCount - persistedTxCount;

  if (countOfNewTxs > 0 && currentTxCount != 0) {
    log(LogLevel.info, '[TX Notifier] Found new transactions');

    for (int i = 0; i < countOfNewTxs; i++) {
      final tx = wallet.txHistory[i];
      if (tx.direction == consts.txDirectionIncoming) {
        log(LogLevel.info, '[TX Notifier] Notifying transaction $i');
        NotificationService().showIncomingTxNotification(tx.amount);
      } else {
        log(LogLevel.info, '[TX Notifier] Not notifying outgoing transaction');
      }
    }

    await wallet.persistTxHistoryCount();
  } else {
    log(LogLevel.info, '[TX Notifier] No new transactions found');
  }

  return true;
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

  // Cancelling will replace an existing task, so we can prevent code from an
  // old release from remaining forever.
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
