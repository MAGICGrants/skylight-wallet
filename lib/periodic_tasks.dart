import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/services/notifications_service.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/services/tor_service.dart';
import 'package:monero_light_wallet/util/logging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:monero_light_wallet/consts.dart' as consts;

class PeriodicTasks {
  static const txNotifier = 'txNotifier';
}

Future<bool> runTxNotifier() async {
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
      onTimeout: () =>
          log(LogLevel.warn, '[TX Notifier] Tor connection timed out'),
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
  final currentTxCount = wallet.txHistory.length;
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

Future<void> registerTxNotifierTaskIfEnabled() async {
  final notificationsIsAllowed = await NotificationService().promptPermission();

  if (!notificationsIsAllowed) {
    await SharedPreferencesService.set<bool>(
      SharedPreferencesKeys.notificationsEnabled,
      false,
    );
    return;
  }

  final notificationsEnabled =
      await SharedPreferencesService.get<bool>(
        SharedPreferencesKeys.notificationsEnabled,
      ) ??
      false;

  if (notificationsEnabled) {
    // This will replace an existing task, so we can prevent code from eg an old
    // release from remaining forever.
    await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
    await Workmanager().registerPeriodicTask(
      "New transactions check",
      PeriodicTasks.txNotifier,
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}

Future<void> unregisterTxNotifierTask() async {
  await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
}

Future<void> registerPeriodicTasks() async {
  await NotificationService().init();
  Workmanager().initialize(_callbackDispatcher, isInDebugMode: true);

  await registerTxNotifierTaskIfEnabled();
}
