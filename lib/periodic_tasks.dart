import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:monero_light_wallet/consts.dart' as consts;

class PeriodicTasks {
  static const newTransactionsCheck = 'newTransactionsCheck';
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final wallet = WalletModel();

    switch (task) {
      case PeriodicTasks.newTransactionsCheck:
        if (!await wallet.hasExistingWallet()) {
          return true;
        }

        await wallet.openExisting();
        await wallet.loadPersistedConnection();
        wallet.connectToDaemon();
        wallet.refresh();

        if (!wallet.isConnected()) {
          return false;
        }

        int itersBeforeSynced = 0;

        while (true) {
          if (wallet.isSynced()) {
            break;
          }

          await Future.delayed(Duration(seconds: 10));

          itersBeforeSynced++;

          if (itersBeforeSynced == 20) {
            return false;
          }
        }

        final persistedTxCount = await wallet.getPersistedTxHistoryCount();
        final currentTxCount = await wallet.getTxHistoryCount();
        final newTxCount = currentTxCount - persistedTxCount;

        if (newTxCount > 0 && currentTxCount != 0) {
          for (int i = 0; i < newTxCount; i++) {
            final tx = wallet.getTxDetails(i);
            if (tx.direction == consts.txDirectionIncoming) {
              NotificationService().showIncomingTxNotification(tx.amount);
            }
          }

          await wallet._persistTxHistoryCount();
        }

        break;
    }

    return true;
  });
}

Future<void> startNewTransactionsCheckTask() async {
  await Workmanager().registerPeriodicTask(
    PeriodicTasks.newTransactionsCheck,
    "New transactions check",
    frequency: Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );
}

Future<void> cancelNewTransactionsCheckTask() async {
  await Workmanager().cancelByUniqueName(PeriodicTasks.newTransactionsCheck);
}
