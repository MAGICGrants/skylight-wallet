import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();

    // push to wallet home screen if wallet exists
    _pushHomeIfWalletExists();
  }

  Future _pushHomeIfWalletExists() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);

    if (await wallet.hasExistingWallet()) {
      await wallet.openExisting();
      await wallet.loadPersistedConnection();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/wallet_home');
      }
    }
  }

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
              i18n.welcomeTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                i18n.welcomeDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/connection_setup'),
              child: Text(i18n.welcomeGetStarted),
            ),
          ],
        ),
      ),
    );
  }
}
