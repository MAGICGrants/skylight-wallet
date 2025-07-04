import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
