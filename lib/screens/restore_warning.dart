import 'package:flutter/material.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';

class RestoreWarningScreen extends StatelessWidget {
  const RestoreWarningScreen({super.key});

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
            Text(
              i18n.restoreWarningTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                i18n.restoreWarningDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/restore_wallet'),
                  child: Text(i18n.restoreWarningContinueButton),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(i18n.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
