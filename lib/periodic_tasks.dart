import 'dart:io';

import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallet_core_glue.dart' show useSharedWalletCore;
import 'package:workmanager/workmanager.dart';

class PeriodicTasks {
  static const txNotifier = 'txNotifier';

  /// iOS BGAppRefreshTask. Opportunistic and short — iOS decides when, and
  /// grants roughly 30 seconds. Only ever scheduled for an LWS connection on
  /// clearnet: a node scan can't finish in that window, and a Tor bootstrap
  /// alone can outlast it.
  static const iosRefresh = 'refresh';

  /// iOS BGProcessingTask. Runs while the device is charging and idle, for
  /// minutes rather than seconds, so Tor has time to come up first. LWS only —
  /// a remote node is never background-synced on iOS.
  static const iosProcessing = 'processing';
}

/// Identifiers must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist
/// and the registrations in AppDelegate.
const _iosBundleId = 'org.magicgrants.skylightwallet';
const _iosRefreshTaskId = '$_iosBundleId.${PeriodicTasks.iosRefresh}';
const _iosProcessingTaskId = '$_iosBundleId.${PeriodicTasks.iosProcessing}';

/// Max wall-clock we let a background run scan before returning, leaving margin
/// under Android's ~10-minute WorkManager budget to persist + notify.
const _backgroundSyncBudget = Duration(minutes: 9);

/// What a BGAppRefreshTask gets on iOS is short and not negotiable; overrunning
/// it means iOS kills the task and schedules the next one less willingly.
const _iosRefreshBudget = Duration(seconds: 25);

/// How often a background run checks on the scan it is waiting for.
const _backgroundSyncPollInterval = Duration(seconds: 5);

/// Consecutive polls without the synced height moving before a run gives up on
/// the rest of its budget. The window has to outlast a refresh cycle: in LWS
/// mode the height only moves when the 20s cycle reloads stats, so a shorter
/// one would read a healthy run as stuck.
const _backgroundSyncStuckPolls = 12;

/// WorkManager's minimum periodic interval.
const _minSyncIntervalMinutes = 15;

/// One background sync pass.
///
/// [budget] is the wall-clock this run may use. [allowTor] and [allowNode] say
/// what the scheduling window can actually accommodate — a 30-second iOS
/// refresh can carry neither a Tor bootstrap nor a node scan. They're checked
/// again here rather than trusted from the scheduler, because iOS can deliver a
/// task that was scheduled under a connection the user has since changed.
Future<bool> runTxNotifier({
  Duration budget = _backgroundSyncBudget,
  bool allowTor = true,
  bool allowNode = true,
}) async {
  final wallet = WalletModel();

  if (!await wallet.hasExistingWallet()) {
    return true;
  }

  // Load the connection first so the correct-mode wallet file is opened.
  await wallet.loadPersistedConnection();

  if (!allowNode && wallet.connectionType == 'node') {
    log(LogLevel.info, '[Background sync] Node connection; not syncing in this window.');
    return true;
  }

  if (!allowTor && wallet.usingTor) {
    log(LogLevel.info, '[Background sync] Tor connection; needs the longer window.');
    return true;
  }

  final backgroundSync =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
      false;

  // A full-node scan is heavy and only runs when Background Sync is on; an LWS
  // wallet always syncs (server-side, cheap). Decided before the wallet is
  // opened: this task stays scheduled for notifications alone, so a node wallet
  // with Background Sync off lands here every cycle, and opening the wallet
  // (with its cached-stats read) is the expensive part of a run that is about
  // to do nothing. Leaving one open would also give the model's own timers
  // something to connect.
  if (wallet.connectionType == 'node' && !backgroundSync) {
    return true;
  }

  await wallet.openExisting();

  if (wallet.usingTor) {
    await TorService.sharedInstance.start();
    final torIsUp = await TorService.sharedInstance.waitUntilConnected(
      timeout: const Duration(minutes: 2),
    );

    if (!torIsUp) {
      log(LogLevel.warn, '[Background sync] Tor did not come up; ending run.');
      return true;
    }
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
  // wait, and stop early once it's synced or once it stops getting anywhere.
  final deadline = DateTime.now().add(budget);
  var lastSyncedHeight = wallet.syncedHeight;
  var stuckPolls = 0;

  while (DateTime.now().isBefore(deadline)) {
    if (wallet.isConnected && wallet.isSynced) break;

    final syncedHeight = wallet.syncedHeight;

    if (syncedHeight != lastSyncedHeight) {
      lastSyncedHeight = syncedHeight;
      stuckPolls = 0;
    } else if (++stuckPolls >= _backgroundSyncStuckPolls) {
      // Unreachable server, dead Tor circuit, stalled scan: holding the wake-up
      // open for the rest of the budget just spends battery to learn nothing.
      log(
        LogLevel.warn,
        '[Background sync] No progress in '
        '${_backgroundSyncStuckPolls * _backgroundSyncPollInterval.inSeconds}s; ending run early.',
      );
      break;
    }

    await Future.delayed(_backgroundSyncPollInterval);
  }

  // Stop the scan and checkpoint it before the isolate goes: nothing closes
  // this wallet, so a refresh left running keeps pulling blocks after the task
  // returns, and the last partial cycle of scanning would be thrown away.
  await wallet.pauseSyncAndStore();

  try {
    await wallet.loadTxHistory();
  } catch (e) {
    log(LogLevel.warn, '[Background sync] loadTxHistory failed: $e');
  }

  try {
    await wallet.notifyNewIncomingTxs();
  } catch (e) {
    log(LogLevel.warn, '[Background sync] notifying new transactions failed: $e');
  }

  return true;
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      // Roughly 30 seconds, whenever iOS feels like it. Enough for an LWS
      // server to report what it has already scanned, and nothing more.
      case PeriodicTasks.iosRefresh:
        return runTxNotifier(budget: _iosRefreshBudget, allowTor: false, allowNode: false);

      // Charging and idle, so there is room for Tor to bootstrap first.
      case PeriodicTasks.iosProcessing:
        return runTxNotifier(allowNode: false);

      case PeriodicTasks.txNotifier:
      default:
        return runTxNotifier();
    }
  });
}

/// (Re)registers background work to match the current settings, or cancels it.
///
/// Call after anything that changes the answer: the notifications toggle, the
/// background-sync toggle, or the connection itself.
Future<void> applyBackgroundTaskRegistration() async {
  // These tasks still drive the legacy WalletModel; under wallet-core they would
  // open the wallet a second time. Skip until they're migrated (Phase 6).
  if (useSharedWalletCore) return;
  if (Platform.isIOS) return _applyIosBackgroundTasks();
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

/// iOS scheduling, which turns on what the connection can actually support.
///
/// A remote node is never background-synced here: neither window is long
/// enough for an on-device scan to be worth the wake-up. For LWS the server has
/// already done the scanning, so a short visit is enough to collect the result.
///
///  - clearnet LWS gets both: the opportunistic refresh for timeliness, and
///    processing as a backstop for when refresh doesn't fire.
///  - Tor LWS gets processing only. Bootstrapping Tor can eat a whole refresh
///    window on its own, so notifications wait for a charging, idle moment.
Future<void> _applyIosBackgroundTasks() async {
  final notifications =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;
  final connectionType =
      await SharedPreferencesService.get<String>(SharedPreferencesKeys.connectionType) ?? 'lws';
  final useTor =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.connectionUseTor) ?? false;

  await Workmanager().cancelByUniqueName(_iosRefreshTaskId);
  await Workmanager().cancelByUniqueName(_iosProcessingTaskId);

  if (!notifications || connectionType == 'node') return;

  if (!useTor) {
    await Workmanager().registerPeriodicTask(
      _iosRefreshTaskId,
      PeriodicTasks.iosRefresh,
      frequency: Duration(minutes: _minSyncIntervalMinutes),
    );
  }

  await Workmanager().registerProcessingTask(
    _iosProcessingTaskId,
    PeriodicTasks.iosProcessing,
    constraints: Constraints(networkType: NetworkType.connected, requiresCharging: true),
  );
}

Future<void> registerPeriodicTasks() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }

  if (useSharedWalletCore) {
    // Not migrated to wallet-core yet. Cancel anything a prior legacy-mode
    // install left scheduled, so WorkManager can't wake a second WalletModel in
    // the background isolate (and stops tracking its constraints).
    await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
    await Workmanager().cancelByUniqueName(_iosRefreshTaskId);
    await Workmanager().cancelByUniqueName(_iosProcessingTaskId);
    return;
  }

  Workmanager().initialize(_callbackDispatcher);
  await applyBackgroundTaskRegistration();
}
