import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';

enum FiatApiMode { torOnly, clearnet, disabled }

// Tracks the latest fiat exchange rate (in [fiatCode]) for every coin
// the wallet supports. Each coin is fetched independently so a Kraken
// outage on one pair doesn't blank out the others.
class FiatRateModel with ChangeNotifier {
  // Mapping coinSymbol -> Kraken base code prefix used to build the
  // pair name. Kraken uses the legacy "X<asset>Z<fiat>" notation for its
  // original assets (e.g. XMR is `XXMRZ`, BTC is `XXBTZ`).
  static const Map<String, String> _krakenBase = {'XMR': 'XXMRZ', 'BTC': 'XXBTZ'};

  static List<String> get supportedCoins => _krakenBase.keys.toList();

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

  /// Clears every persisted per-coin rate. Called when the user changes the fiat currency or
  /// API mode so the UI doesn't briefly show a stale rate quoted in the previous fiat.
  static Future<void> clearPersistedRates() async {
    for (final coin in _krakenBase.keys) {
      await SharedPreferencesService.remove(_persistKeyFor(coin));
    }
  }

  final Map<String, double?> _rates = {};
  bool _isLoading = false;
  bool _hasFailed = false;
  bool _isDisabled = false;
  String _fiatCode = 'USD';
  FiatApiMode _fiatApiMode = FiatApiMode.torOnly;
  Timer? _rateFetchTimer;
  WalletManager? _walletManager;
  Set<String> _lastFetchedActiveCoins = {};

  /// Latest fiat rate for [coinSymbol], or `null` if it hasn't been
  /// fetched yet (or the most recent fetch failed). Returns `null` for
  /// unconfigured coins. Testnet wallets always return `0`.
  double? rateFor(String coinSymbol, {bool? walletActive, bool? isTestnet}) {
    final symbol = coinSymbol.toUpperCase();
    final wallet = _walletManager?.getWallet(symbol);
    if (isTestnet == true || wallet?.isTestnet == true) return 0;
    if (walletActive == false) return null;
    if (wallet != null && wallet.connectionAddress.isEmpty) return null;
    return _rates[symbol];
  }

  Map<String, double?> get rates => Map.unmodifiable(_rates);
  bool get isLoading => _isLoading;
  bool get hasFailed => _hasFailed;
  bool get isDisabled => _isDisabled;
  String get fiatCode => _fiatCode;

  static String _persistKeyFor(String coinSymbol) =>
      '${SharedPreferencesKeys.fiatRate}_${coinSymbol.toLowerCase()}';

  void attachWalletManager(WalletManager manager) {
    if (identical(_walletManager, manager)) return;
    _walletManager?.removeListener(_onWalletManagerChanged);
    _walletManager = manager;
    manager.addListener(_onWalletManagerChanged);
  }

  void _onWalletManagerChanged() {
    final active = _activeKrakenCoins().toSet();
    if (_setEquals(active, _lastFetchedActiveCoins)) return;
    if (_rateFetchTimer != null && !_isDisabled) {
      _loadRate();
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }

  Iterable<String> _activeKrakenCoins() {
    final manager = _walletManager;
    if (manager == null) return [];
    return manager.allWallets
        .where((w) => w.connectionAddress.isNotEmpty && !w.isTestnet)
        .map((w) => w.coinSymbol.toUpperCase())
        .where(_krakenBase.containsKey);
  }

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
    _fiatApiMode = await FiatRateModel.loadFiatApiMode();
    for (final coin in _krakenBase.keys) {
      _rates[coin] = await SharedPreferencesService.get<double>(_persistKeyFor(coin));
    }
  }

  Future<void> _persist(String coin, double rate) async {
    await SharedPreferencesService.set<double>(_persistKeyFor(coin), rate);
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

  /// Fetches the rate for one coin, applying the USD->fiat bridge for
  /// fiat codes Kraken doesn't quote directly.
  Future<double> _fetchCoinRate(String coin) async {
    final krakenBase = _krakenBase[coin]!;
    final isIndirect = indirectPairCurrencies.contains(_fiatCode);
    final pair1 = isIndirect ? '${krakenBase}USD' : '$krakenBase$_fiatCode';
    final pair2 = isIndirect ? 'USDT$_fiatCode' : null;

    final rates = await Future.wait([
      _requestPairRate(pair1),
      pair2 != null ? _requestPairRate(pair2) : Future.value(null),
    ]);
    return rates[0]! * (rates[1] ?? 1);
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

    _isLoading = true;
    notifyListeners();

    final coinsToFetch = _activeKrakenCoins().toList();
    _lastFetchedActiveCoins = coinsToFetch.toSet();

    if (coinsToFetch.isEmpty) {
      _hasFailed = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    var anySucceeded = false;
    var anyFailed = false;

    await Future.wait(
      coinsToFetch.map((coin) async {
        try {
          final rate = await _fetchCoinRate(coin);
          _rates[coin] = rate;
          await _persist(coin, rate);
          anySucceeded = true;
          log(LogLevel.info, '$_fiatCode/$coin rate: $rate');
        } catch (error) {
          log(LogLevel.error, 'Failed to get $coin/$_fiatCode rate. $error');
          anyFailed = true;
        }
      }),
    );

    _hasFailed = anyFailed && !anySucceeded;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> startService({WalletManager? walletManager}) async {
    if (walletManager != null) {
      attachWalletManager(walletManager);
    }
    _rateFetchTimer?.cancel();
    _rateFetchTimer = null;
    await _loadPersisted();
    _startRateFetchTimer();
  }
}
