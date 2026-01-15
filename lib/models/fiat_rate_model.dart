import 'dart:async';
import 'package:flutter/material.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';

class FiatRateModel with ChangeNotifier {
  double? _rate;
  bool _isLoading = false;
  bool _hasFailed = false;
  bool _isDisabled = false;
  String _fiatCode = 'USD';
  Timer? _rateFetchTimer;

  double? get rate => _rate;
  bool get isLoading => _isLoading;
  bool get hasFailed => _hasFailed;
  bool get isDisabled => _isDisabled;
  String get fiatCode => _fiatCode;

  void _startRateFetchTimer() {
    if (TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      _isDisabled = true;
      log(LogLevel.info, 'Tor is disabled. Not starting rate fetch timer.');
      return;
    } else {
      _isDisabled = false;
    }

    if (_rateFetchTimer != null) {
      _rateFetchTimer?.cancel();
    }

    _loadRate();

    _rateFetchTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      if (TorSettingsService.sharedInstance.torMode != TorMode.disabled) {
        _loadRate();
      } else {
        log(LogLevel.info, 'Tor is disabled. Stopping rate fetch timer.');
        timer.cancel();
        _rateFetchTimer = null;
      }
    });
  }

  Future<void> _loadPersisted() async {
    _fiatCode =
        await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatCurrency) ?? 'USD';
    _rate = await SharedPreferencesService.get<double>(SharedPreferencesKeys.fiatRate);
  }

  Future<void> _persist(double rate) async {
    await SharedPreferencesService.set<double>(SharedPreferencesKeys.fiatRate, rate);
  }

  Future<double> _requestPairRate(String pair) async {
    final url = 'https://api.kraken.com/0/public/Ticker?pair=$pair';
    final proxyInfo = await TorSettingsService.sharedInstance.getProxy();

    log(LogLevel.info, 'Fetching rate from fiat api:');
    log(LogLevel.info, '  url: $url');
    log(LogLevel.info, '  proxyInfo: $proxyInfo');

    if (proxyInfo == null) {
      throw Exception('Not fetching rate from fiat API because Tor is disabled');
    }

    try {
      final response = await makeSocksHttpRequest('GET', url, proxyInfo);
      if (response.statusCode == 200) {
        final rate = response.jsonBody['result']?[pair]?['o'];
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

  Future<void> _loadRate() async {
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
    await _loadPersisted();
    _startRateFetchTimer();
  }
}
