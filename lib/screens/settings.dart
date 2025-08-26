import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/language_model.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/periodic_tasks.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// The state class for the SettingsScreen.
class _SettingsScreenState extends State<SettingsScreen> {
  bool _newTxNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() async {
    final newTxNotificationsEnabled =
        await SharedPreferencesService.get<bool>(
          SharedPreferencesKeys.notificationsEnabled,
        ) ??
        false;

    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
    });
  }

  void _setNewTxNotifications(bool value) async {
    setState(() {
      _newTxNotificationsEnabled = value;
    });

    if (value) {
      startNewTransactionsCheckTask();
    } else {
      cancelNewTransactionsCheckTask();
    }

    await SharedPreferencesService.set<bool>(
      SharedPreferencesKeys.notificationsEnabled,
      value,
    );
  }

  void _showDeleteWalletDialog() {
    final i18n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(i18n.settingsDeleteWalletButton),
        content: Text(i18n.settingsDeleteWalletDialogText),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.cancel),
            label: Text(i18n.cancel),
          ),
          TextButton.icon(
            onPressed: _deleteWallet,
            icon: Icon(Icons.delete_forever),
            label: Text(i18n.settingsDeleteWalletDialogDeleteButton),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _deleteWallet() {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.delete();
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) => {
          if (index == 0) {Navigator.pushNamed(context, '/wallet_home')},
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.wallet),
            label: i18n.navigationBarSettings,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: i18n.navigationBarSettings,
          ),
        ],
      ),
      appBar: AppBar(title: Text(i18n.settingsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i18n.settingsNotifyNewTxs, style: TextStyle(fontSize: 18)),
                Switch(
                  value: _newTxNotificationsEnabled,
                  onChanged: _setNewTxNotifications,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  i18n.settingsLanguageLabel,
                  style: TextStyle(fontSize: 18),
                ),
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
            Container(
              margin: EdgeInsets.only(top: 20),
              child: TextButton.icon(
                onPressed: _showDeleteWalletDialog,
                label: Text(i18n.settingsDeleteWalletButton),
                icon: Icon(Icons.delete),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
