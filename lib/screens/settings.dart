import 'package:flutter/material.dart';
import 'package:monero_light_wallet/consts.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/language_model.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/periodic_tasks.dart';
import 'package:monero_light_wallet/services/notifications_service.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
import 'package:monero_light_wallet/widgets/wallet_navigation_bar.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _newTxNotificationsEnabled = false;
  var _fiatCurrency = 'USD';

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

    final fiatCurrency =
        await SharedPreferencesService.get<String>(
          SharedPreferencesKeys.fiatCurrency,
        ) ??
        'USD';

    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _fiatCurrency = fiatCurrency;
    });
  }

  void _setNewTxNotifications(bool value) async {
    setState(() {
      _newTxNotificationsEnabled = value;
    });

    if (value) {
      final isAllowed = await NotificationService().promptPermission();

      if (isAllowed) {
        startNewTransactionsCheckTask();
        await SharedPreferencesService.set<bool>(
          SharedPreferencesKeys.notificationsEnabled,
          true,
        );
      }
    } else {
      cancelNewTransactionsCheckTask();
      await SharedPreferencesService.set<bool>(
        SharedPreferencesKeys.notificationsEnabled,
        false,
      );
    }
  }

  void _setFiatCurrency(String? value) async {
    if (value == null) return;

    setState(() {
      _fiatCurrency = value;
    });

    await SharedPreferencesService.set<String>(
      SharedPreferencesKeys.fiatCurrency,
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

  Future<void> _deleteWallet() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    await wallet.delete();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/welcome',
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  i18n.settingsDisplayCurrencyLabel,
                  style: TextStyle(fontSize: 18),
                ),
                DropdownButton<String>(
                  value: _fiatCurrency,
                  onChanged: _setFiatCurrency,
                  items: supportedFiatCurrencies.map((fiatCode) {
                    return DropdownMenuItem<String>(
                      value: fiatCode,
                      child: Text(fiatCode),
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
