import 'dart:async';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/wallet_password.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_testnet_wallet.dart';
import 'package:skylight_wallet/wallets/coins/bitcoin/bitcoin_wallet.dart';
import 'package:skylight_wallet/wallets/coins/monero/monero_wallet.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';
import 'package:skylight_wallet/wallets/master_seed_store.dart';

/// Top-level state holder shared by every screen.
///
/// Owns every supported [CryptoWallet] (currently only [MoneroWallet]) and
/// orchestrates flows that touch all of them: opening from a stored
/// password, restoring from a BIP39 master seed, deleting, etc. Each child
/// wallet is its own [ChangeNotifier]; the manager re-broadcasts their
/// notifications so widgets that only watch the manager still update when
/// any individual wallet changes.
class WalletManager with ChangeNotifier {
  /// All supported coins, keyed by their `coinSymbol` (uppercase).
  final Map<String, CryptoWallet> _wallets;

  String? _password;

  bool _testnetCoinsEnabled = false;

  WalletManager() : _wallets = {} {
    _register(MoneroWallet());
    _register(BitcoinWallet());
    _register(BitcoinTestnetWallet());
  }

  /// Loads persisted app preferences that affect which wallets are shown.
  Future<void> loadPreferences() async {
    _testnetCoinsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.testnetCoinsEnabled) ??
        false;
    _applyTestnetVisibility();
    notifyListeners();
  }

  bool get testnetCoinsEnabled => _testnetCoinsEnabled;

  Future<void> setTestnetCoinsEnabled(bool enabled) async {
    if (_testnetCoinsEnabled == enabled) return;
    _testnetCoinsEnabled = enabled;
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.testnetCoinsEnabled, enabled);
    _applyTestnetVisibility();
    notifyListeners();
    if (enabled && _password != null) {
      openWalletFilesAndSync();
    }
  }

  void _applyTestnetVisibility() {
    for (final w in _wallets.values) {
      if (w.isTestnet) {
        w.setEnabledInApp(_testnetCoinsEnabled);
      }
    }
  }

  bool _isWalletVisible(CryptoWallet w) => !w.isTestnet || _testnetCoinsEnabled;

  Iterable<CryptoWallet> get _visibleWallets => _wallets.values.where(_isWalletVisible);

  void _register(CryptoWallet wallet) {
    _wallets[wallet.coinSymbol] = wallet;
    wallet.addListener(_onWalletChanged);
  }

  Timer? _notifyDebounce;

  void _onWalletChanged() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(Duration(milliseconds: 100), () {
      notifyListeners();
    });
  }

  // ----- Public surface -----

  Map<String, CryptoWallet> get wallets => Map.unmodifiable(_wallets);
  List<CryptoWallet> get allWallets => List.unmodifiable(_visibleWallets);
  List<CryptoWallet> get activeWallets =>
      _visibleWallets.where((w) => w.isActive).toList(growable: false);
  List<CryptoWallet> get loadedWallets =>
      _visibleWallets.where((w) => w.isLoaded).toList(growable: false);

  CryptoWallet? getWallet(String coinSymbol) {
    final wallet = _wallets[coinSymbol.toUpperCase()];
    if (wallet == null || !_isWalletVisible(wallet)) return null;
    return wallet;
  }

  /// True if the user has set the shared wallet password in this session
  /// (or it was just loaded from secure storage on mobile).
  bool get hasPassword => _password != null;

  // ----- Password -----

  void setWalletPassword(String password) {
    _password = password;
  }

  /// Sets a freshly generated random password. Used on mobile onboarding,
  /// where the user authenticates via the device (biometrics/PIN) instead of
  /// typing a password; the generated value is persisted to secure storage by
  /// [restoreAll].
  void useGeneratedPassword() {
    _password = genWalletPassword();
  }

  /// Clears the in-memory password (e.g. when the app is backgrounded with
  /// app lock enabled). The next unlock reloads it from secure storage.
  void clearPassword() {
    _password = null;
  }

  /// Persists the current password to mobile secure storage. No-op on
  /// desktop (the user is expected to enter the password on every unlock).
  Future<void> persistMobileWalletPassword() async {
    if (_password == null) {
      throw StateError('Cannot persist password: none set');
    }
    if (Platform.isAndroid || Platform.isIOS) {
      await storeMobileWalletPassword(_password!);
    }
  }

  /// Attempts to load the wallet password from mobile secure storage. On
  /// desktop this is a no-op and returns false.
  Future<bool> loadMobileWalletPassword() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final stored = await getMobileWalletPassword();
    if (stored == null) return false;
    _password = stored;
    return true;
  }

  // ----- Lifecycle across all wallets -----

  /// True if at least one wallet has a persisted file on disk.
  Future<bool> hasAnyExistingWallet() async {
    for (final w in _wallets.values) {
      if (await w.hasExistingWallet()) return true;
    }
    return false;
  }

  /// Opens every wallet that has a file on disk using the shared
  /// password. Use [password] to override the in-memory password (e.g.
  /// from the desktop unlock screen).
  ///
  /// When [displayOnly] is true, only restores connection settings and
  /// cached balance/tx display — no wallet files or network I/O.
  Future<void> openAll({String? password, bool displayOnly = false}) async {
    if (password != null) {
      _password = password;
    }

    await loadCachedDisplayState();

    if (displayOnly) return;

    if (_password == null) {
      final loaded = await loadMobileWalletPassword();
      if (!loaded) {
        log(LogLevel.warn, '[WalletManager] openAll called without a password');
        return;
      }
    }

    await _openWalletFiles();
  }

  /// Restores persisted connection settings and cached balances/tx lists.
  /// Fast — intended to run before navigating to the home screen.
  Future<void> loadCachedDisplayState() async {
    await loadPreferences();
    await Future.wait(
      _visibleWallets.map((w) async {
        try {
          await w.loadPersistedConnection();
          await w.loadPersistedSnapshot();
        } catch (e) {
          log(LogLevel.error, 'Failed to load cached display state: $e', coin: w.coinSymbol);
        }
      }),
    );
  }

  /// Opens on-disk wallet files (slow; Monero FFI, decrypt, etc.).
  /// Concurrent callers share one in-flight open.
  Future<void> _openWalletFiles() async {
    _openWalletFilesInFlight ??= _openWalletFilesOnce();
    await _openWalletFilesInFlight!;
  }

  Future<void>? _openWalletFilesInFlight;

  Future<void> _openWalletFilesOnce() async {
    try {
      ({String mnemonic, DateTime restoreDate})? masterSeed;
      try {
        masterSeed = await MasterSeedStore.load(_password!);
      } catch (e) {
        log(LogLevel.error, '[WalletManager] Failed to read master seed: $e');
      }

      // Fan out so per-wallet opens (each runs in its own isolate or FFI
      // thread) overlap. A failure in one wallet must not cancel the others.
      await Future.wait([
        for (final w in _visibleWallets) _openOneWallet(w, masterSeed),
      ]);
    } finally {
      _openWalletFilesInFlight = null;
    }
  }

  Future<void> _openOneWallet(
    CryptoWallet w,
    ({String mnemonic, DateTime restoreDate})? masterSeed,
  ) async {
    // Coins that don't need wallet state for their daemon connect (e.g.
    // Bitcoin Electrum) can hand-shake in the shadow of the file open so the
    // background sync that follows already has a live socket. Don't await:
    // a slow Tor handshake must not stall the open path, and `load()` will
    // dedupe via the connect's in-flight future.
    unawaited(_connectBeforeOpenSafely(w));

    try {
      if (await w.hasExistingWallet()) {
        final timer = Stopwatch()..start();
        await w.openExisting(password: _password!);
        timer.stop();
        log(
          LogLevel.info,
          'Wallet opened in ${timer.elapsedMilliseconds}ms',
          coin: w.coinSymbol,
        );
      } else if (masterSeed != null) {
        log(LogLevel.info, 'Bootstrapping from master seed.', coin: w.coinSymbol);
        await w.restoreFromMasterSeed(
          bip39Mnemonic: masterSeed.mnemonic,
          restoreDate: masterSeed.restoreDate,
          password: _password!,
        );
      }
    } catch (e) {
      log(LogLevel.error, 'Failed to open: $e', coin: w.coinSymbol);
      if (masterSeed != null && _isCorruptWalletFile(e)) {
        try {
          log(
            LogLevel.warn,
            'Removing corrupt wallet file and re-bootstrapping.',
            coin: w.coinSymbol,
          );
          await w.deleteFiles();
          await w.restoreFromMasterSeed(
            bip39Mnemonic: masterSeed.mnemonic,
            restoreDate: masterSeed.restoreDate,
            password: _password!,
          );
        } catch (e2) {
          log(LogLevel.error, 'Failed to re-bootstrap: $e2', coin: w.coinSymbol);
        }
      }
    }
  }

  Future<void> _connectBeforeOpenSafely(CryptoWallet w) async {
    if (!w.canConnectBeforeOpen) return;
    try {
      final timer = Stopwatch()..start();
      await w.connectBeforeOpen();
      timer.stop();
      log(
        LogLevel.info,
        'Pre-open connect in ${timer.elapsedMilliseconds}ms',
        coin: w.coinSymbol,
      );
    } catch (e) {
      log(LogLevel.warn, 'Pre-open connect failed: $e', coin: w.coinSymbol);
    }
  }

  /// Opens wallet files then syncs active coins in the background.
  void openWalletFilesAndSync() {
    unawaited(() async {
      if (_password == null) {
        await loadMobileWalletPassword();
      }
      if (_password == null) return;
      await _openWalletFiles();
      syncInBackground();
    }());
  }

  /// Steady-state refresh for every configured wallet.
  Future<void> loadAll() async {
    for (final w in _visibleWallets) {
      if (!w.isActive) continue;
      await w.load();
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Opens wallets if needed, then refreshes active ones without blocking the UI.
  Future<void> bootstrap() async {
    await loadCachedDisplayState();
    if (loadedWallets.isEmpty) {
      if (_password == null) {
        await loadMobileWalletPassword();
      }
      if (_password != null) {
        await _openWalletFiles();
      }
    }
    syncInBackground();
  }

  /// Refreshes every configured wallet in the background.
  void syncInBackground() {
    unawaited(loadAll());
  }

  static bool _isCorruptWalletFile(Object error) {
    if (error is! FormatException) return false;
    final msg = error.message.toLowerCase();
    return msg.contains('too short') ||
        msg.contains('magic mismatch') ||
        msg.contains('corrupt') ||
        msg.contains('decryption failed') ||
        msg.contains('unsupported wallet blob');
  }

  /// Generates a brand new 15-word BIP39 mnemonic + restore date for display.
  /// No wallets are created or persisted until [restoreAll] is called (after
  /// the user confirms they've written the seed down).
  ({String mnemonic, DateTime restoreDate}) generateSeed() {
    return (mnemonic: bip39.generateMnemonic(strength: 160), restoreDate: DateTime.now());
  }

  /// Restores wallets for every supported coin from the same BIP39 master
  /// seed. Throws if no password has been set.
  Future<void> restoreAll({required String bip39Mnemonic, required DateTime restoreDate}) async {
    if (_password == null) {
      throw StateError('Wallet password must be set before restoring wallets.');
    }
    if (!bip39.validateMnemonic(bip39Mnemonic)) {
      throw Exception('Invalid mnemonic.');
    }

    for (final w in _visibleWallets) {
      await w.restoreFromMasterSeed(
        bip39Mnemonic: bip39Mnemonic,
        restoreDate: restoreDate,
        password: _password!,
      );
    }

    // Persist the master seed so coins added in future releases can be
    // bootstrapped on next unlock without re-prompting for the seed.
    await MasterSeedStore.save(
      bip39Mnemonic: bip39Mnemonic,
      restoreDate: restoreDate,
      password: _password!,
    );

    await persistMobileWalletPassword();

    // Load persisted connections so the home screen shows configured servers.
    for (final w in _visibleWallets) {
      await w.loadPersistedConnection();
    }
  }

  /// Deletes every wallet file and clears every wallet's namespaced prefs
  /// plus the shared (cross-coin) keys.
  Future<void> deleteAll() async {
    for (final w in _wallets.values) {
      try {
        await w.delete();
      } catch (e) {
        log(LogLevel.error, 'Failed to delete: $e', coin: w.coinSymbol);
      }
    }

    try {
      await MasterSeedStore.delete();
    } catch (e) {
      log(LogLevel.error, '[WalletManager] Failed to delete master seed: $e');
    }

    _password = null;

    await SharedPreferencesService.remove(SharedPreferencesKeys.appLockEnabled);
    await SharedPreferencesService.remove(SharedPreferencesKeys.pendingOutgoingTxs);
    await SharedPreferencesService.remove(SharedPreferencesKeys.contacts);
  }

  // ----- Aggregate getters -----

  /// Sum of unlocked balance × fiat rate across all coins. Missing rates
  /// count as zero so the home-screen total never waits on a fetch.
  double totalUnlockedFiat(Map<String, double?> ratesBySymbol) {
    double total = 0;
    for (final w in _visibleWallets) {
      if (w.isTestnet) continue;
      final balance = w.unlockedBalance ?? 0;
      final rate = ratesBySymbol[w.coinSymbol] ?? 0;
      total += balance * rate;
    }
    return total;
  }

  @override
  void dispose() {
    _notifyDebounce?.cancel();
    for (final w in _wallets.values) {
      w.removeListener(_onWalletChanged);
      w.dispose();
    }
    super.dispose();
  }
}
