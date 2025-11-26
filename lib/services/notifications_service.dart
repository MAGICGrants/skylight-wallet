import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const initSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'Open wallet',
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      linux: initSettingsLinux,
    );

    await notificationsPlugin.initialize(initSettings);
  }

  Future<bool> promptPermission() async {
    final status = await Permission.notification.status;

    if (!status.isGranted) {
      final result = await Permission.notification.request();
      return result.isGranted;
    }

    return true;
  }

  Future<void> showIncomingTxNotification(double amountReceived) async {
    await notificationsPlugin.show(
      0,
      'Incoming transaction',
      'You received $amountReceived XMR',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'incoming_transactions',
          'Transactions',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}
