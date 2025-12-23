import 'package:flutter/material.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';

class TorInfoScreen extends StatelessWidget {
  const TorInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Monero Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(i18n.torInfoTitle, style: Theme.of(context).textTheme.headlineMedium),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                i18n.torInfoDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/tor_settings'),
                  child: Text(i18n.torInfoConfigureButton),
                ),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/connection_setup'),
                  child: Text(i18n.torInfoContinueButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
