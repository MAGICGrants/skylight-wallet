import 'package:workmanager/workmanager.dart';

import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:wallet_background/wallet_background.dart';

// The orchestration lives in wallet-core (`wallet_background`); the app keeps
// only the isolate entry point, because a fresh background isolate has none of
// the app's wallet-core statics and the package can't reach the app's bootstrap.
export 'package:wallet_background/wallet_background.dart'
    show PeriodicTasks, registerPeriodicTasks, applyBackgroundTaskRegistration;

/// WorkManager isolate entry: bootstrap this isolate (`installWalletCore` also
/// installs the `BackgroundSync` config), then run the shared orchestration.
/// Top-level `@pragma` so it survives tree-shaking.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    installWalletCore();
    return dispatchBackgroundTask(task);
  });
}
