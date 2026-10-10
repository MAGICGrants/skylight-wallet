import 'package:wallet_infra/wallet_infra.dart' show SettingsKeys;

// The prefs service itself lives in wallet-core (injectable, test-seamed). Kept
// under the same import path so call sites are unchanged.
export 'package:wallet_infra/wallet_infra.dart' show SharedPreferencesService;

/// Skylight's preference keys. The common ones reference the shared [SettingsKeys]
/// so the key strings can't drift from spice; only skylight-specific keys (the
/// Monero connection + wallet-state keys) are literals here.
class SharedPreferencesKeys {
  static const String language = SettingsKeys.language;
  static const String fiatCurrency = SettingsKeys.fiatCurrency;
  static const String fiatApiMode = SettingsKeys.fiatApiMode;
  static const String fiatAutoDisabledByTor = SettingsKeys.fiatAutoDisabledByTor;
  static const String fiatRate = SettingsKeys.fiatRate;
  static const String theme = SettingsKeys.theme;
  static const String notificationsEnabled = SettingsKeys.notificationsEnabled;
  static const String backgroundSyncEnabled = SettingsKeys.backgroundSyncEnabled;
  static const String foregroundSyncEnabled = SettingsKeys.foregroundSyncEnabled;
  static const String backgroundSyncIntervalMinutes = SettingsKeys.backgroundSyncIntervalMinutes;
  static const String appLockEnabled = SettingsKeys.appLockEnabled;
  static const String verboseLoggingEnabled = SettingsKeys.verboseLoggingEnabled;
  static const String contacts = SettingsKeys.contacts;
  static const String torMode = SettingsKeys.torMode;
  static const String torSocksPort = SettingsKeys.torSocksPort;
  static const String torUseOrbot = SettingsKeys.torUseOrbot;

  // Skylight-only (Monero connection + wallet state):
  static const String connectionAddress = 'connectionAddress';
  static const String connectionProxyPort = 'connectionProxyPort';
  static const String connectionUseTor = 'connectionUseTor';
  static const String connectionUseSsl = 'connectionUseSsl';
  static const String connectionType = 'connectionType';
  static const String serverSupportsSubaddresses = 'serverSupportsSubaddresses';
  static const String walletRestoreHeight = 'walletRestoreHeight';
  static const String unusedSubaddressIndex = 'unusedSubaddressIndex';
  static const String unusedSubaddressIndexIsSupported = 'unusedSubaddressIndexIsSupported';
}
