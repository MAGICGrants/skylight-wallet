import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'incoming_transactions',
      'Incoming transactions',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

const NotificationDetails platformChannelSpecifics = NotificationDetails(
  android: androidPlatformChannelSpecifics,
);
