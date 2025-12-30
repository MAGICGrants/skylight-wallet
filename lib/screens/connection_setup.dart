import 'dart:io';
import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';

class ConnectionSetupScreen extends StatelessWidget {
  const ConnectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    void onSaved() {
      // On desktop platforms, navigate to password screen first
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        Navigator.pushNamed(context, '/create_wallet_password');
      } else {
        Navigator.pushNamed(context, '/create_wallet');
      }
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
                      i18n.connectionSetupTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      i18n.connectionSetupDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                ConnectionSettingsForm(
                  saveButtonLabel: i18n.connectionSetupContinueButton,
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
