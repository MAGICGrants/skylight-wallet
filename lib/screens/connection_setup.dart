import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';

class ConnectionSetupScreen extends StatelessWidget {
  const ConnectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    void onSaved() {
      Navigator.pushNamed(context, '/fiat_api_setup');
    }

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
                Column(
                  spacing: 10,
                  children: [
                    Text(
                      i18n.lwsSetupTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      i18n.lwsSetupDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                ConnectionSettingsForm(
                  saveButtonLabel: i18n.lwsSetupContinueButton,
                  onSaved: onSaved,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
