import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';

class LanguageModel with ChangeNotifier {
  String _language = PlatformDispatcher.instance.locale.languageCode;

  String get language => _language;

  LanguageModel() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final String? preferencesLanguage =
        await SharedPreferencesService.get<String>(
          SharedPreferencesKeys.language,
        );

    if (preferencesLanguage != null) {
      _language = preferencesLanguage;
      notifyListeners();
    }
  }

  void setLanguage(String? newLanguage) async {
    if (newLanguage == null) return;

    _language = newLanguage;

    await SharedPreferencesService.set<String>(
      SharedPreferencesKeys.language,
      newLanguage,
    );

    notifyListeners();
  }
}
