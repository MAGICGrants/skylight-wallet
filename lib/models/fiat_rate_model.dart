import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skylight_wallet/consts.dart';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';

class FiatRateModel with ChangeNotifier {
  double? _rate;
  bool _hasFailed = false;
  String _fiatCode = 'USD';
  Timer? _rateFetchTimer;

  double? get rate => _rate;
  bool get hasFailed => _hasFailed;
  String get fiatCode => _fiatCode;

  FiatRateModel() {
    _loadPersisted();
    _startTorStatusCheckTimer();
  }

  void _startTorStatusCheckTimer() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (TorService.sharedInstance.status == TorConnectionStatus.connected &&
          _rateFetchTimer == null) {
        _startRateFetchTimer();
        _loadRate();
      }
    });
  }

  void _startRateFetchTimer() {
    _rateFetchTimer = Timer.periodic(Duration(minutes: 10), (timer) async {
      if (TorService.sharedInstance.status == TorConnectionStatus.connected) {
        await _loadRate();
      } else {
        timer.cancel();
        _rateFetchTimer = null;
      }
    });
  }

  Future<void> _loadPersisted() async {
    _fiatCode =
        await SharedPreferencesService.get<String>(
          SharedPreferencesKeys.fiatCurrency,
        ) ??
        'USD';

    _fiatCode = fiatCode;

    final rate = await SharedPreferencesService.get<double>(
      SharedPreferencesKeys.fiatRate,
    );

    _rate = rate;
  }

  Future<void> _persist(double rate) async {
    await SharedPreferencesService.set<double>(
      SharedPreferencesKeys.fiatRate,
      rate,
    );
  }

  Future<double> _requestPairRate(String pair) async {
    final url = 'https://api.kraken.com/0/public/Ticker?pair=$pair';
    final proxyInfo = TorService.sharedInstance.getProxyInfo();

    log(LogLevel.info, 'Fetching rate from fiat api:');
    log(LogLevel.info, '  url: $url');
    log(LogLevel.info, '  proxyInfo: $proxyInfo');

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
  }

  Future<void> _loadRate() async {
    final fiatCode =
        await SharedPreferencesService.get<String>(
          SharedPreferencesKeys.fiatCurrency,
        ) ??
        'USD';

    _fiatCode = fiatCode;

    final pair1 = indirectPairCurrencies.contains(fiatCode)
        ? 'XXMRZUSD'
        : 'XXMRZ$fiatCode';

    final pair2 = indirectPairCurrencies.contains(fiatCode)
        ? 'USDT$fiatCode'
        : null;

    try {
      final rates = await Future.wait([
        _requestPairRate(pair1),
        pair2 != null ? _requestPairRate(pair2) : Future.value(null),
      ]);

      final finalRate = rates[0]! * (rates[1] ?? 1);
      _rate = finalRate;
      _persist(finalRate);
      _hasFailed = false;
      log(LogLevel.info, '$fiatCode rate: $finalRate');
    } catch (error) {
      log(LogLevel.error, 'Failed to get fiat rate. ${error.toString()}');
      _hasFailed = true;
    }

    notifyListeners();
  }

  Future<void> reset() async {
    await _loadPersisted();

    if (TorService.sharedInstance.status == TorConnectionStatus.connected) {
      await _loadRate();
    }
  }
}
