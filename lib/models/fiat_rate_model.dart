import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';

enum FiatApiMode { torOnly, clearnet, disabled }

class FiatRateModel with ChangeNotifier {
  static Future<FiatApiMode> loadFiatApiMode() async {
    final s = await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatApiMode);
    if (s == null) {
      return FiatApiMode.torOnly;
    }
    for (final m in FiatApiMode.values) {
      if (m.name == s) return m;
    }
    return FiatApiMode.torOnly;
  }

  static Future<void> saveFiatApiMode(FiatApiMode mode) async {
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatApiMode, mode.name);
  }

  double? _rate;
  bool _isLoading = false;
  bool _hasFailed = false;
  bool _isDisabled = false;
  String _fiatCode = 'USD';
  FiatApiMode _fiatApiMode = FiatApiMode.torOnly;
  Timer? _rateFetchTimer;

  double? get rate => _rate;
  bool get isLoading => _isLoading;
  bool get hasFailed => _hasFailed;
  bool get isDisabled => _isDisabled;
  String get fiatCode => _fiatCode;

  void _startRateFetchTimer() {
    if (_fiatApiMode == FiatApiMode.disabled) {
      _isDisabled = true;
      log(LogLevel.info, 'Fiat API is disabled. Not starting rate fetch timer.');
      return;
    } else {
      _isDisabled = false;
    }

    _rateFetchTimer?.cancel();

    _loadRate();

    _rateFetchTimer = Timer.periodic(Duration(minutes: 10), (_) {
      _loadRate();
    });
  }

  Future<void> _loadPersisted() async {
    _fiatCode =
        await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatCurrency) ?? 'USD';
    _rate = await SharedPreferencesService.get<double>(SharedPreferencesKeys.fiatRate);
    _fiatApiMode = await FiatRateModel.loadFiatApiMode();
  }

  Future<void> _persist(double rate) async {
    await SharedPreferencesService.set<double>(SharedPreferencesKeys.fiatRate, rate);
  }

  Future<double> _requestPairRateClearnet(String pair) async {
    final url = 'https://api.kraken.com/0/public/Ticker?pair=$pair';
    log(LogLevel.info, 'Fetching rate from fiat api (clearnet): $url');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('Status code: ${response.statusCode}');
      }
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;
      final rate = jsonBody['result']?[pair]?['o'];
      if (rate is! String) {
        throw Exception('Could not find rate for $pair');
      }
      return double.parse(rate);
    } finally {
      client.close(force: true);
    }
  }

  Future<double> _requestPairRateTor(String pair) async {
    final url = 'https://api.kraken.com/0/public/Ticker?pair=$pair';
    final proxyInfo = await TorSettingsService.sharedInstance.getProxy();

    log(LogLevel.info, 'Fetching rate from fiat api (Tor):');
    log(LogLevel.info, '  url: $url');
    log(LogLevel.info, '  proxyInfo: $proxyInfo');

    if (proxyInfo == null) {
      throw Exception('Not fetching rate from fiat API because no Tor proxy is available');
    }

    try {
      final response = await makeSocksHttpRequest('GET', url, proxyInfo);
      if (response.statusCode == 200) {
        final rate = response.jsonBody?['result']?[pair]?['o'];
        if (rate is! String) {
          throw Exception('Could not find rate for $pair');
        }
        return double.parse(rate);
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (error) {
      log(LogLevel.error, 'Failed to get fiat rate. ${error.toString()}');
      throw Exception('Failed to get fiat rate. ${error.toString()}');
    }
  }

  Future<double> _requestPairRate(String pair) async {
    if (_fiatApiMode == FiatApiMode.clearnet) {
      try {
        return await _requestPairRateClearnet(pair);
      } catch (error) {
        log(LogLevel.error, 'Failed to get fiat rate. ${error.toString()}');
        throw Exception('Failed to get fiat rate. ${error.toString()}');
      }
    }
    return _requestPairRateTor(pair);
  }

  Future<void> _loadRate() async {
    _fiatApiMode = await FiatRateModel.loadFiatApiMode();
    if (_fiatApiMode == FiatApiMode.disabled) {
      _rateFetchTimer?.cancel();
      _rateFetchTimer = null;
      _isDisabled = true;
      notifyListeners();
      return;
    }
    _isDisabled = false;

    _fiatCode =
        await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatCurrency) ?? 'USD';

    final pair1 = indirectPairCurrencies.contains(_fiatCode) ? 'XXMRZUSD' : 'XXMRZ$_fiatCode';
    final pair2 = indirectPairCurrencies.contains(fiatCode) ? 'USDT$fiatCode' : null;

    try {
      _isLoading = true;
      notifyListeners();

      final rates = await Future.wait([
        _requestPairRate(pair1),
        pair2 != null ? _requestPairRate(pair2) : Future.value(null),
      ]);

      final finalRate = rates[0]! * (rates[1] ?? 1);
      _rate = finalRate;
      _persist(finalRate);
      _hasFailed = false;
      log(LogLevel.info, '$_fiatCode rate: $finalRate');
    } catch (error) {
      log(LogLevel.error, 'Failed to get fiat rate. ${error.toString()}');
      _hasFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startService() async {
    _rateFetchTimer?.cancel();
    _rateFetchTimer = null;
    await _loadPersisted();
    _startRateFetchTimer();
  }
}
