import 'dart:io';

import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final wallet = WalletModel();

    switch (task) {
      case "simplePeriodicTask":
        await wallet.openExisting();
        final connection = await wallet.getPersistedConnection();

        wallet.setConnection(
          connection.address,
          connection.proxyPort,
          connection.useSsl,
        );

        wallet.connectToDaemon();

        while (!wallet.isSynced()) {
          sleep(Duration(seconds: 10));
        }

        final persistedTxCount = await wallet.getPersistedTxHistoryCount();
        final currentTxCount = await wallet.getTxHistoryCount();
        final newTxCount = currentTxCount - persistedTxCount;

        if (newTxCount > 0 && currentTxCount != 0) {
          // notify!

          await wallet.persistTxHistoryCount();
        }

        break;
    }

    // Return true if the task was successful, false if it needs to be retried
    return Future.value(true);
  });
}
