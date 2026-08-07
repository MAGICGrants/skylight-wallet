import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallet_core_glue.dart' show useSharedWalletCore;

/// Android foreground service that keeps the Monero wallet syncing while the
/// app is backgrounded — a persistent-notification alternative to the
/// budget-limited WorkManager task. Dies on force-quit (OS limitation).

const _channelId = 'skylight_background_sync';
const _channelName = 'Background sync';

/// Entry point run inside the foreground-service isolate. Must be top-level.
@pragma('vm:entry-point')
void foregroundSyncCallback() {
  FlutterForegroundTask.setTaskHandler(_SyncTaskHandler());
}

class _SyncTaskHandler extends TaskHandler {
  WalletModel? _wallet;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final wallet = WalletModel();
    _wallet = wallet;
    try {
      if (!await wallet.hasExistingWallet()) return;
      // Load the connection first so the correct-mode wallet file is opened.
      await wallet.loadPersistedConnection();
      await wallet.openExisting();

      if (wallet.usingTor) {
        await TorService.sharedInstance.start();
        if (!await TorService.sharedInstance.waitUntilConnected(
          timeout: const Duration(minutes: 2),
        )) {
          log(LogLevel.warn, '[FG sync] Tor did not come up; not connecting.');
          return;
        }
      }

      if (wallet.connectionAddress.isEmpty) return;
      // Connect; the wallet's own timers then drive the scan + checkpoints for
      // as long as this service keeps the isolate alive.
      try {
        await wallet.connectToDaemon();
      } catch (e) {
        log(LogLevel.warn, '[FG sync] connect failed: $e');
      }
    } catch (e) {
      log(LogLevel.warn, '[FG sync] start failed: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final wallet = _wallet;
    final syncing =
        wallet != null &&
        wallet.connectionAddress.isNotEmpty &&
        !(wallet.isConnected && wallet.isSynced);
    FlutterForegroundTask.updateService(
      notificationTitle: 'Skylight Wallet',
      notificationText: syncing ? 'Syncing…' : 'Wallet up to date',
    );

    // While this service is running it is the thing watching the chain, so it
    // is the thing that has to announce what it finds. The background task runs
    // on its own schedule and would otherwise never see these.
    if (wallet != null) {
      unawaited(
        wallet.notifyNewIncomingTxs().catchError((Object e) {
          log(LogLevel.warn, '[FG sync] notifying new transactions failed: $e');
        }),
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    final wallet = _wallet;
    _wallet = null;

    // Stop the scan and checkpoint it: the service is going away but nothing
    // closes the wallet, and the scanning done since the last checkpoint would
    // otherwise be lost.
    if (wallet != null) {
      try {
        await wallet.pauseSyncAndStore();
      } catch (e) {
        log(LogLevel.warn, '[FG sync] Failed to store on shutdown: $e');
      }
    }
  }
}

/// Configures the service. Safe to call more than once.
void initForegroundSync() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: _channelId,
      channelName: _channelName,
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(30000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> startForegroundSync() async {
  // Runs the legacy WalletModel in its own isolate; under wallet-core that opens
  // the wallet a second time. Skip until it's migrated (Phase 6).
  if (useSharedWalletCore) return;
  if (!Platform.isAndroid) return;
  initForegroundSync();
  await FlutterForegroundTask.requestNotificationPermission();
  if (await FlutterForegroundTask.isRunningService) return;
  await FlutterForegroundTask.startService(
    notificationTitle: 'Skylight Wallet',
    notificationText: 'Syncing…',
    callback: foregroundSyncCallback,
  );
}

Future<void> stopForegroundSync() async {
  if (!Platform.isAndroid) return;
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}

/// Starts the service on launch if the user enabled it, so backgrounding keeps
/// syncing.
Future<void> startForegroundSyncIfEnabled() async {
  if (!Platform.isAndroid) return;
  final enabled =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.foregroundSyncEnabled) ??
      false;
  if (enabled) await startForegroundSync();
}
