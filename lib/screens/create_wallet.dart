import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';

class CreateWalletScreen extends StatelessWidget {
  const CreateWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Monero Light Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(
              i18n.createWalletTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                i18n.createWalletDescription,
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
                      Navigator.pushNamed(context, '/restore_warning'),
                  child: Text(i18n.createWalletRestoreExistingButton),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/generate_seed'),
                  child: Text(i18n.createWalletCreateNewButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
