import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/widgets/fiat_api_settings_form.dart';
import 'package:spice_wallet/widgets/tor_settings_form.dart';
import 'package:spice_wallet/models/language_model.dart';
import 'package:spice_wallet/models/theme_model.dart';
import 'package:spice_wallet/wallets/wallet_manager.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _newTxNotificationsEnabled = false;
  var _appLockEnabled = false;
  var _verboseLoggingEnabled = false;
  var _testnetCoinsEnabled = false;
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

    final appLockEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.appLockEnabled) ?? false;

    final verboseLoggingEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
        false;

    final testnetCoinsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.testnetCoinsEnabled) ??
        false;

    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _appLockEnabled = appLockEnabled;
      _verboseLoggingEnabled = verboseLoggingEnabled;
      _testnetCoinsEnabled = testnetCoinsEnabled;
    });
  }

  void _setTestnetCoinsEnabled(bool value) async {
    setState(() {
      _testnetCoinsEnabled = value;
    });

    final manager = Provider.of<WalletManager>(context, listen: false);
    await manager.setTestnetCoinsEnabled(value);

    if (mounted) {
      final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
      fiatRate.startService(walletManager: manager);
    }
  }

  void _setTxNotificationsEnabled(bool value) async {
    if (value) {
      final isAllowed = await NotificationService().promptPermission();
      if (!isAllowed) {
        setState(() => _newTxNotificationsEnabled = false);
        return;
      }
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, true);
    } else {
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
    }
    setState(() => _newTxNotificationsEnabled = value);
    await applyBackgroundTaskRegistration();
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

  void _exportLogs() async {
    final i18n = AppLocalizations.of(context)!;

    try {
      final logFiles = await getLogFiles();

      if (logFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.settingsExportLogsError)));
        }
        return;
      }

      if (mounted) {
        _showExportLogsDialog(logFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.settingsExportLogsError)));
      }
    }
  }

  void _showExportLogsDialog(List<LogFileInfo> logFiles) {
    final i18n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        constraints: BoxConstraints.tightFor(width: dialogWidth),
        insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Text(i18n.settingsExportLogsLabel),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: logFiles.length,
            itemBuilder: (context, index) {
              final file = logFiles[index];
              final dateStr =
                  '${file.modified.year}-${file.modified.month.toString().padLeft(2, '0')}-${file.modified.day.toString().padLeft(2, '0')}';
              final sizeKb = (file.size / 1024).toStringAsFixed(1);

              return ListTile(
                onTap: () async {
                  Navigator.pop(context);
                  await exportLogFiles([file]);
                },
                leading: Icon(Icons.description_outlined),
                title: Text(file.name),
                subtitle: Text('$dateStr • $sizeKb KB'),
                trailing: Icon(Icons.ios_share),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.cancel))],
      ),
    );
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

  Future<void> _deleteWallet() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    // Tear down background sync first so its isolate can't re-create wallet
    // files right after we delete them, and clear the settings so it doesn't
    // re-register on next launch.
    await stopForegroundSync();
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, false);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, false);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
    await applyBackgroundTaskRegistration();

    await manager.deleteAll();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (Route<dynamic> route) => false);
    }
  }

  void _showTorSettingsDialog() {
    final i18n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    Future<void> onSaved() async {
      final manager = Provider.of<WalletManager>(context, listen: false);
      manager.syncInBackground();

      final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
      fiatRate.startService(walletManager: manager);

      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        constraints: BoxConstraints.tightFor(width: dialogWidth),
        insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Text(i18n.torSettingsTitle),
        content: TorSettingsForm(saveButtonLabel: i18n.torSettingsSaveButton, onSaved: onSaved),
      ),
    );
  }

  void _showFiatApiSettingsDialog() {
    final i18n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        constraints: BoxConstraints.tightFor(width: dialogWidth),
        insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Text(i18n.settingsFiatApiSettingsLabel),
        content: FiatApiSettingsForm(
          saveButtonLabel: i18n.torSettingsSaveButton,
          onSaved: () async {
            final manager = Provider.of<WalletManager>(context, listen: false);
            final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
            await fiatRate.startService(walletManager: manager);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();
    final theme = context.watch<ThemeModel>();

    return Scaffold(
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 2),
      appBar: AppBar(title: Text(i18n.settingsTitle)),
      body: SingleChildScrollView(
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
            if (Platform.isAndroid || Platform.isIOS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(i18n.settingsAppLockLabel, style: TextStyle(fontSize: 18)),
                  Switch(value: _appLockEnabled, onChanged: _setAppLockEnabled),
                ],
              ),
            if (Platform.isAndroid)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n.settingsNotifyNewTxsLabel, style: TextStyle(fontSize: 18)),
                        Text(
                          i18n.settingsNotifyNewTxsMoneroNodeHint,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
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
                      Text(i18n.settingsTestnetCoinsLabel, style: TextStyle(fontSize: 18)),
                      Text(
                        i18n.settingsTestnetCoinsDescription,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(value: _testnetCoinsEnabled, onChanged: _setTestnetCoinsEnabled),
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
                        Platform.isIOS
                            ? i18n.settingsVerboseLoggingDescriptionIos
                            : i18n.settingsVerboseLoggingDescription,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(value: _verboseLoggingEnabled, onChanged: _setVerboseLoggingEnabled),
              ],
            ),
            if (Platform.isIOS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(i18n.settingsExportLogsLabel, style: TextStyle(fontSize: 18)),
                  TextButton.icon(
                    onPressed: _verboseLoggingEnabled ? _exportLogs : null,
                    icon: Icon(Icons.ios_share),
                    label: Text(i18n.settingsExportLogsButton),
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsTorSettingsLabel, style: TextStyle(fontSize: 18)),
                TextButton.icon(
                  onPressed: _showTorSettingsDialog,
                  icon: Icon(Icons.security),
                  label: Text(i18n.settingsLwsViewKeysButton),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsFiatApiSettingsLabel, style: TextStyle(fontSize: 18)),
                TextButton.icon(
                  onPressed: _showFiatApiSettingsDialog,
                  icon: Icon(Icons.currency_exchange),
                  label: Text(i18n.settingsLwsViewKeysButton),
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
            SizedBox(height: 20),
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
                'Spice Wallet v$_appVersion (build $_buildNumber)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
