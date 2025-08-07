import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesKeys {
  static const String notificationsEnabled = 'notificationsEnabled';
}

class SharedPreferencesService {
  SharedPreferencesService._();

  static Future<T?> get<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String keyString = key.toString();

    switch (T) {
      case bool:
        return prefs.getBool(keyString) as T?;
      case String:
        return prefs.getString(keyString) as T?;
      case int:
        return prefs.getInt(keyString) as T?;
      case double:
        return prefs.getDouble(keyString) as T?;
      default:
        return null;
    }
  }

  static Future<void> set<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    final String keyString = key.toString();

    if (value is bool) {
      await prefs.setBool(keyString, value);
    } else if (value is String) {
      await prefs.setString(keyString, value);
    } else if (value is int) {
      await prefs.setInt(keyString, value);
    } else if (value is double) {
      await prefs.setDouble(keyString, value);
    }
  }
}
