import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

class NotificationService {
  // Per-isolate: the background task and the foreground service each get their
  // own engine, and the plugin has to be initialized in whichever one is about
  // to show something.
  static bool _initialized = false;

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;

    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      // We'll request permissions manually
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Open wallet');

    // Windows requires an absolute path to an .ico file
    final initSettingsWindows = WindowsInitializationSettings(
      appName: 'Skylight Wallet',
      appUserModelId: 'org.magicgrants.skylight',
      guid: '6dcf17a9-fb5f-4f47-b0b9-6d655e90adbf',
      iconPath: Platform.isWindows
          ? p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', 'assets', 'app_icon.ico')
          : null,
    );

    final initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
      linux: initSettingsLinux,
      windows: initSettingsWindows,
    );

    await notificationsPlugin.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> promptPermission() async {
    if (Platform.isIOS) {
      // Use flutter_local_notifications' iOS-specific permission request
      final iosPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      final granted = await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

      return granted ?? false;
    } else if (Platform.isAndroid) {
      // Android 13+ needs runtime permission
      final androidPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? true; // Older Android versions don't need permission
    }

    return true; // Other platforms (Linux, etc.)
  }

  Future<void> showIncomingTxNotification(double amountReceived) async {
    // Cheap when already done, and the only way this works from a background
    // isolate, which never ran the init in main().
    await init();

    const notificationChannelId = 'incoming_transactions';

    await notificationsPlugin.show(
      0,
      'Incoming transaction',
      'You received $amountReceived XMR',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Transactions',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: notificationChannelId),
      ),
    );
  }
}
