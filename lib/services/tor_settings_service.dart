import 'dart:io';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';

enum TorMode { builtIn, external, disabled }

class TorSettingsService {
  static final TorSettingsService sharedInstance = TorSettingsService._();

  TorMode _torMode = TorMode.builtIn;
  String _socksPort = '9050';
  bool _useOrbot = false;

  TorMode get torMode => _torMode;
  String get socksPort => _socksPort;
  bool get useOrbot => _useOrbot;

  TorSettingsService._();

  Future<void> loadSettings() async {
    final String? torModeString = await SharedPreferencesService.get<String>(
      SharedPreferencesKeys.torMode,
    );
    final String? socksPortString = await SharedPreferencesService.get<String>(
      SharedPreferencesKeys.torSocksPort,
    );
    final bool? useOrbotValue = await SharedPreferencesService.get<bool>(
      SharedPreferencesKeys.torUseOrbot,
    );

    if (torModeString != null) {
      _torMode = _torModeFromString(torModeString);
    }

    if (socksPortString != null) {
      _socksPort = socksPortString;
    }

    if (useOrbotValue != null) {
      _useOrbot = useOrbotValue;
    }
  }

  Future<void> save({required TorMode torMode, String? socksPort, bool? useOrbot}) async {
    _torMode = torMode;
    await SharedPreferencesService.set<String>(
      SharedPreferencesKeys.torMode,
      _torModeToString(torMode),
    );

    if (socksPort != null) {
      _socksPort = socksPort;
      await SharedPreferencesService.set<String>(SharedPreferencesKeys.torSocksPort, socksPort);
    }

    if (useOrbot != null) {
      _useOrbot = useOrbot;
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.torUseOrbot, useOrbot);
    }
  }

  Future<({InternetAddress host, int port})?> getProxy() async {
    if (_torMode == TorMode.builtIn) {
      await TorService.sharedInstance.waitUntilConnected();
      print('getProxyInfo builtIn: ${TorService.sharedInstance.getProxyInfo()}');
      return TorService.sharedInstance.getProxyInfo();
    } else if (_torMode == TorMode.external) {
      print(
        'getProxyInfo external: (host: InternetAddress.loopbackIPv4, port: ${int.parse(_socksPort)})',
      );
      return (host: InternetAddress.loopbackIPv4, port: int.parse(_socksPort));
    } else {
      print('getProxyInfo disabled: null');
      return null;
    }
  }

  String _torModeToString(TorMode mode) {
    switch (mode) {
      case TorMode.builtIn:
        return 'builtIn';
      case TorMode.external:
        return 'external';
      case TorMode.disabled:
        return 'disabled';
    }
  }

  TorMode _torModeFromString(String modeString) {
    switch (modeString) {
      case 'builtIn':
        return TorMode.builtIn;
      case 'external':
        return TorMode.external;
      case 'disabled':
        return TorMode.disabled;
      default:
        return TorMode.builtIn;
    }
  }
}
