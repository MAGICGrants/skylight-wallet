import 'package:flutter/material.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/tor_settings_form.dart';

class TorSettingsScreen extends StatelessWidget {
  const TorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Monero Wallet')),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                Text(i18n.torSettingsTitle, style: Theme.of(context).textTheme.headlineMedium),
                TorSettingsForm(
                  saveButtonLabel: i18n.continueText,
                  onSaved: () => Navigator.pushNamed(context, '/connection_setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
