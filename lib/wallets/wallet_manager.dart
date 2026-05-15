import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';

import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/wallet_password.dart';
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

  WalletManager() : _wallets = {} {
    _register(MoneroWallet());
    _register(BitcoinWallet());
  }

  void _register(CryptoWallet wallet) {
    _wallets[wallet.coinSymbol] = wallet;
    wallet.addListener(_onWalletChanged);
  }

  void _onWalletChanged() => notifyListeners();

  // ----- Public surface -----

  Map<String, CryptoWallet> get wallets => Map.unmodifiable(_wallets);
  List<CryptoWallet> get allWallets => List.unmodifiable(_wallets.values);
  List<CryptoWallet> get activeWallets =>
      _wallets.values.where((w) => w.isActive).toList(growable: false);
  List<CryptoWallet> get loadedWallets =>
      _wallets.values.where((w) => w.isLoaded).toList(growable: false);

  CryptoWallet? getWallet(String coinSymbol) => _wallets[coinSymbol.toUpperCase()];

  /// True if the user has set the shared wallet password in this session
  /// (or it was just loaded from secure storage on mobile).
  bool get hasPassword => _password != null;

  // ----- Password -----

  void setWalletPassword(String password) {
    _password = password;
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
  Future<void> openAll({String? password}) async {
    if (password != null) {
      _password = password;
    }
    if (_password == null) {
      // Mobile auto-unlock path: try secure storage.
      final loaded = await loadMobileWalletPassword();
      if (!loaded) {
        log(LogLevel.warn, '[WalletManager] openAll called without a password');
        return;
      }
    }

    // Load the master seed (if any) up-front so we can bootstrap any
    // coin that was added after the wallet was originally created.
    ({String mnemonic, DateTime restoreDate})? masterSeed;
    try {
      masterSeed = await MasterSeedStore.load(_password!);
    } catch (e) {
      log(LogLevel.error, '[WalletManager] Failed to read master seed: $e');
    }

    for (final w in _wallets.values) {
      try {
        if (await w.hasExistingWallet()) {
          await w.openExisting(password: _password!);
        } else if (masterSeed != null) {
          // Coin was added after the wallet existed (or its file was
          // never written for some reason). Lazily bootstrap it from
          // the persisted BIP39 master seed.
          log(LogLevel.info, '[WalletManager] Bootstrapping ${w.coinSymbol} from master seed.');
          await w.restoreFromMasterSeed(
            bip39Mnemonic: masterSeed.mnemonic,
            restoreDate: masterSeed.restoreDate,
            password: _password!,
          );
        }
      } catch (e) {
        log(LogLevel.error, '[WalletManager] Failed to open ${w.coinSymbol}: $e');
      }

      // Always restore any persisted connection state, even if the
      // wallet couldn't be opened/bootstrapped — the user shouldn't
      // lose their server settings on restart.
      try {
        await w.loadPersistedConnection();
      } catch (e) {
        log(LogLevel.error, '[WalletManager] Failed to load ${w.coinSymbol} connection: $e');
      }
    }
  }

  /// Steady-state refresh for every loaded wallet.
  Future<void> loadAll() async {
    for (final w in _wallets.values) {
      if (w.isLoaded) {
        w.load();
      }
    }
  }

  /// Generates a brand new 15-word BIP39 mnemonic, restores wallets for
  /// every supported coin from it, and returns the mnemonic so the UI can
  /// display it to the user along with the restore date.
  Future<({String mnemonic, DateTime restoreDate})> createFromNewSeed() async {
    final mnemonic = bip39.generateMnemonic(strength: 160);
    final restoreDate = DateTime.now();
    await restoreAll(bip39Mnemonic: mnemonic, restoreDate: restoreDate);
    return (mnemonic: mnemonic, restoreDate: restoreDate);
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

    for (final w in _wallets.values) {
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
  }

  /// Deletes every wallet file and clears every wallet's namespaced prefs
  /// plus the shared (cross-coin) keys.
  Future<void> deleteAll() async {
    for (final w in _wallets.values) {
      try {
        await w.delete();
      } catch (e) {
        log(LogLevel.error, '[WalletManager] Failed to delete ${w.coinSymbol}: $e');
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

  /// Sum of `unlockedBalance` across active wallets, weighted by each
  /// wallet's fiat rate. Wallets whose balance or rate is `null` are
  /// skipped.
  double? totalUnlockedFiat(Map<String, double?> ratesBySymbol) {
    double total = 0;
    var anyKnown = false;
    for (final w in activeWallets) {
      final balance = w.unlockedBalance;
      final rate = ratesBySymbol[w.coinSymbol];
      if (balance == null || rate == null) continue;
      total += balance * rate;
      anyKnown = true;
    }
    return anyKnown ? total : null;
  }

  @override
  void dispose() {
    for (final w in _wallets.values) {
      w.removeListener(_onWalletChanged);
      w.dispose();
    }
    super.dispose();
  }
}
