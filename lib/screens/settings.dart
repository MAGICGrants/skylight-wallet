import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/models/theme_model.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/periodic_tasks.dart';
import 'package:skylight_wallet/services/notifications_service.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/widgets/wallet_navigation_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _newTxNotificationsEnabled = false;
  var _fiatCurrency = 'USD';
  var _appLockEnabled = false;
  var _verboseLoggingEnabled = false;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadPackageInfo();
  }

  void _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  void _loadPreferences() async {
    final newTxNotificationsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ??
        false;

    final fiatCurrency =
        await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatCurrency) ?? 'USD';

    final appLockEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.appLockEnabled) ?? false;

    final verboseLoggingEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
        false;

    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _fiatCurrency = fiatCurrency;
      _appLockEnabled = appLockEnabled;
      _verboseLoggingEnabled = verboseLoggingEnabled;
    });
  }

  void _setTxNotificationsEnabled(bool value) async {
    setState(() {
      _newTxNotificationsEnabled = value;
    });

    if (value) {
      final isAllowed = await NotificationService().promptPermission();

      if (isAllowed) {
        await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, true);
        await registerTxNotifierTaskIfAllowed();
      }
    } else {
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
      await unregisterPeriodicTasks();
    }
  }

  void _setAppLockEnabled(bool value) async {
    final i18n = AppLocalizations.of(context)!;

    if (value) {
      final auth = LocalAuthentication();

      try {
        final didAuthenticate = await auth.authenticate(
          localizedReason: i18n.settingsAppLockUnlockReason,
          options: AuthenticationOptions(useErrorDialogs: true, sensitiveTransaction: true),
        );

        if (!didAuthenticate) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(i18n.settingsAppLockUnableToAuthError)));
          }
          return;
        }
      } catch (error) {
        log(LogLevel.error, 'Unable to authenticate: ${error.toString()}');

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.settingsAppLockUnableToAuthError)));
        }
        return;
      }
    }

    setState(() {
      _appLockEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.appLockEnabled, value);
  }

  void _setVerboseLoggingEnabled(bool value) async {
    setState(() {
      _verboseLoggingEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.verboseLoggingEnabled, value);
  }

  void _setFiatCurrency(String? value) async {
    if (value == null) return;

    setState(() {
      _fiatCurrency = value;
    });

    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, value);

    // Clear rate
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatRate);

    if (mounted) {
      final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
      await fiatRate.reset();
    }
  }

  void _showDeleteWalletDialog() {
    final i18n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth.clamp(0.0, 500.0);

        return AlertDialog(
          constraints: BoxConstraints.tightFor(width: dialogWidth),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          title: Row(
            spacing: 6,
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              Text(i18n.settingsDeleteWalletButton),
            ],
          ),
          content: Text(i18n.settingsDeleteWalletDialogText),
          actions: [
            TextButton.icon(
              onPressed: _deleteWallet,
              icon: Icon(Icons.delete_forever),
              label: Text(i18n.settingsDeleteWalletDialogDeleteButton),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.cancel),
              label: Text(i18n.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showViewLwsKeysDialog() {
    final i18n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth.clamp(0.0, 500.0);

        return AlertDialog(
          constraints: BoxConstraints.tightFor(width: dialogWidth),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          title: Row(
            spacing: 6,
            children: [
              Icon(Icons.warning, color: Colors.orange),
              Text(i18n.warning),
            ],
          ),
          content: Text(i18n.settingsViewLwsKeysDialogText),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/lws_keys');
              },
              icon: Icon(Icons.warning),
              label: Text(i18n.settingsViewLwsKeysDialogRevealButton),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.cancel),
              label: Text(i18n.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showViewSecretKeysDialog() {
    final i18n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth.clamp(0.0, 500.0);

        return AlertDialog(
          constraints: BoxConstraints.tightFor(width: dialogWidth),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          title: Row(
            spacing: 6,
            children: [
              Icon(Icons.warning, color: Colors.red),
              Text(i18n.warning),
            ],
          ),
          content: Text(i18n.settingsViewSecretKeysDialogText),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/secret_keys');
              },
              icon: Icon(Icons.warning),
              label: Text(i18n.settingsViewSecretKeysDialogRevealButton),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.cancel),
              label: Text(i18n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWallet() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    await wallet.delete();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();
    final theme = context.watch<ThemeModel>();

    return Scaffold(
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 2),
      appBar: AppBar(title: Text(i18n.settingsTitle)),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsThemeLabel, style: TextStyle(fontSize: 18)),
                DropdownButton<String>(
                  value: theme.theme,
                  onChanged: theme.setTheme,
                  items: [
                    DropdownMenuItem<String>(
                      value: 'system',
                      child: Text(i18n.settingsThemeSystem),
                    ),
                    DropdownMenuItem<String>(value: 'light', child: Text(i18n.settingsThemeLight)),
                    DropdownMenuItem<String>(value: 'dark', child: Text(i18n.settingsThemeDark)),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsLanguageLabel, style: TextStyle(fontSize: 18)),
                DropdownButton<String>(
                  value: language.language,
                  onChanged: language.setLanguage,
                  items: AppLocalizations.supportedLocales.map((Locale locale) {
                    return DropdownMenuItem<String>(
                      value: locale.languageCode,
                      child: Text(locale.languageCode.toUpperCase()),
                    );
                  }).toList(),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsDisplayCurrencyLabel, style: TextStyle(fontSize: 18)),
                DropdownButton<String>(
                  value: _fiatCurrency,
                  onChanged: _setFiatCurrency,
                  items: supportedFiatCurrencies.map((fiatCode) {
                    return DropdownMenuItem<String>(value: fiatCode, child: Text(fiatCode));
                  }).toList(),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsAppLockLabel, style: TextStyle(fontSize: 18)),
                Switch(value: _appLockEnabled, onChanged: _setAppLockEnabled),
              ],
            ),
            if (Platform.isAndroid || Platform.isIOS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(i18n.settingsNotifyNewTxsLabel, style: TextStyle(fontSize: 18)),
                  Switch(value: _newTxNotificationsEnabled, onChanged: _setTxNotificationsEnabled),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.settingsVerboseLoggingLabel, style: TextStyle(fontSize: 18)),
                      Text(
                        i18n.settingsVerboseLoggingDescription,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(value: _verboseLoggingEnabled, onChanged: _setVerboseLoggingEnabled),
              ],
            ),
            Container(margin: EdgeInsetsGeometry.symmetric(vertical: 10), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsLwsViewKeysLabel, style: TextStyle(fontSize: 18)),
                TextButton.icon(
                  onPressed: _showViewLwsKeysDialog,
                  icon: Icon(Icons.key),
                  label: Text(i18n.settingsLwsViewKeysButton),
                  style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Colors.orange)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsSecretKeysLabel, style: TextStyle(fontSize: 18)),
                TextButton.icon(
                  onPressed: _showViewSecretKeysDialog,
                  icon: Icon(Icons.key),
                  label: Text(i18n.settingsSecretKeysButton),
                  style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Colors.red)),
                ),
              ],
            ),
            Container(margin: EdgeInsetsGeometry.symmetric(vertical: 10), child: Divider()),
            TextButton.icon(
              onPressed: _showDeleteWalletDialog,
              label: Text(i18n.settingsDeleteWalletButton),
              icon: Icon(Icons.delete),
              style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Colors.red)),
            ),
            Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/terms_of_service'),
              child: Text('Terms of Service'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/privacy_policy'),
              child: Text('Privacy Policy'),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Skylight Wallet v$_appVersion (build $_buildNumber)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
