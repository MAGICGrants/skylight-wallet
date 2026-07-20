import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesKeys {
  static const String language = 'language';
  static const String fiatCurrency = 'fiatCurrency';
  static const String fiatApiMode = 'fiatApiMode';
  static const String fiatRate = 'fiatRate';
  static const String theme = 'theme';
  static const String notificationsEnabled = 'notificationsEnabled';
  static const String appLockEnabled = 'appLockEnabled';
  static const String verboseLoggingEnabled = 'verboseLoggingEnabled';
  static const String pendingOutgoingTxs = 'pendingOutgoingTxs';
  static const String contacts = 'contacts';
  static const String torMode = 'torMode';
  static const String torSocksPort = 'torSocksPort';
  static const String torUseOrbot = 'torUseOrbot';
  static const String testnetCoinsEnabled = 'testnetCoinsEnabled';
  static const String backgroundSyncEnabled = 'backgroundSyncEnabled';
  static const String backgroundSyncIntervalMinutes = 'backgroundSyncIntervalMinutes';
  static const String foregroundSyncEnabled = 'foregroundSyncEnabled';
}

class SharedPreferencesService {
  SharedPreferencesService._();

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<T?> get<T>(String key) async {
    final prefs = await _instance();
    final String keyString = key.toString();

    switch (T) {
      // ignore: type_literal_in_constant_pattern
      case bool:
        return prefs.getBool(keyString) as T?;
      // ignore: type_literal_in_constant_pattern
      case String:
        return prefs.getString(keyString) as T?;
      // ignore: type_literal_in_constant_pattern
      case int:
        return prefs.getInt(keyString) as T?;
      // ignore: type_literal_in_constant_pattern
      case double:
        return prefs.getDouble(keyString) as T?;
      default:
        return null;
    }
  }

  static Future<void> set<T>(String key, T value) async {
    final prefs = await _instance();
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

  static Future<void> remove(String key) async {
    final prefs = await _instance();
    await prefs.remove(key);
  }
}
