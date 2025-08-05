import 'package:flutter/material.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:provider/provider.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> {
  late List<String> seed;

  @override
  void initState() {
    super.initState();
    final wallet = Provider.of<WalletModel>(context, listen: false);
    seed = wallet.generatePolyseed().split(' ');
  }

  void _continue() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.connectToDaemon();
    print(seed.join(' '));
    print(wallet.getCurrentHeight());

    await wallet.restoreFromMnemonic(
      seed.join(' '),
      wallet.getCurrentHeight() - 1000,
    );
    wallet.store();
    Navigator.pushReplacementNamed(context, '/wallet_home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsetsGeometry.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(
                'New Wallet',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This is your polyseed. Write it down and keep it in a safe place.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: seed.map((word) {
                  return Chip(label: Text(word));
                }).toList(),
              ),
              ElevatedButton(
                onPressed: _continue,
                child: const Text('I wrote it down'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
