import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      // We'll request permissions manually
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Open wallet');

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
      linux: initSettingsLinux,
    );

    await notificationsPlugin.initialize(initSettings);
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
