import 'package:flutter/material.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';

class ThemeModel with ChangeNotifier {
  String _theme = 'system';

  String get theme => _theme;

  ThemeModel() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final String? preferencesTheme = await SharedPreferencesService.get<String>(
      SharedPreferencesKeys.theme,
    );

    if (preferencesTheme != null) {
      _theme = preferencesTheme;
    }
    notifyListeners();
  }

  void setTheme(String? newTheme) async {
    if (newTheme == null) return;

    _theme = newTheme;

    await SharedPreferencesService.set<String>(
      SharedPreferencesKeys.theme,
      newTheme,
    );

    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
