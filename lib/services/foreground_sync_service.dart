import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:wallet_background/wallet_background.dart';

// The handler + service control live in wallet-core (`wallet_background`); the
// app keeps only the isolate entry point (see periodic_tasks.dart).
export 'package:wallet_background/wallet_background.dart'
    show startForegroundSync, stopForegroundSync, startForegroundSyncIfEnabled, isWalletFullySynced;

/// Foreground-service isolate entry: bootstrap this isolate, then hand off to
/// the shared handler. Top-level `@pragma` so it survives tree-shaking.
@pragma('vm:entry-point')
void foregroundSyncCallback() {
  installWalletCore();
  FlutterForegroundTask.setTaskHandler(BackgroundSyncTaskHandler());
}
