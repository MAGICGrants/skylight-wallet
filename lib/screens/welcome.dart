import 'package:flutter/material.dart';
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
      wallet.openExisting();
      Navigator.pushReplacementNamed(context, '/wallet_home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Monero Light Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text('Welcome!', style: Theme.of(context).textTheme.headlineMedium),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Light Monero Wallet is one of the simplest Monero wallets. We will help you set up a wallet and connect to a server.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/create_wallet'),
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
