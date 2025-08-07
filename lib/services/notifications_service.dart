import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const initSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: initSettingsAndroid);

    await notificationsPlugin.initialize(initSettings);
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
