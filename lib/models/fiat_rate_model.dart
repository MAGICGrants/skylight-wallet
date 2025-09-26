import 'dart:async';
import 'package:flutter/material.dart';

import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/services/tor_service.dart';
import 'package:monero_light_wallet/util/logging.dart';
import 'package:monero_light_wallet/util/socks_http.dart';

class FiatRateModel with ChangeNotifier {
  double? _rate;
  bool _hasFailed = false;
  String _fiatCode = 'USD';
  Timer? rateFetchTimer;

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
          rateFetchTimer == null) {
        _startRateFetchTimer();
      }
    });
  }

  void _startRateFetchTimer() {
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (TorService.sharedInstance.status == TorConnectionStatus.connected) {
        _fetch();
      } else {
        timer.cancel();
        rateFetchTimer = null;
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

  Future<void> _fetch() async {
    final fiatCode =
        await SharedPreferencesService.get<String>(
          SharedPreferencesKeys.fiatCurrency,
        ) ??
        'USD';

    _fiatCode = fiatCode;

    final pair = 'XXMRZ$fiatCode';
    final url = 'https://api.kraken.com/0/public/Ticker?pair=$pair';

    final proxyInfo = TorService.sharedInstance.getProxyInfo();

    try {
      final response = await makeSocksHttpRequest('GET', url, proxyInfo);

      if (response.statusCode == 200) {
        final rate = response.jsonBody['result']?[pair]?['o'];

        if (rate is String) {
          _rate = double.parse(rate);
          _persist(double.parse(rate));
          _hasFailed = false;
        } else {
          log(LogLevel.error, 'Failed to get fiat rate.', response.jsonBody);
          _hasFailed = true;
        }
      } else {
        log(LogLevel.error, 'Failed to get fiat rate.', response.jsonBody);
        _hasFailed = true;
      }
    } catch (error) {
      log(LogLevel.error, 'Failed to get fiat rate.');
      log(LogLevel.error, error.toString());
      _hasFailed = true;
    }

    notifyListeners();
  }

  Future<void> reset() async {
    _loadPersisted();

    if (TorService.sharedInstance.status == TorConnectionStatus.connected) {
      await _fetch();
    }
  }
}
