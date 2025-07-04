import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> {
  String _mnemonic = '';
  int _restoreHeight = 0;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletModel>();

    return Scaffold(
      appBar: AppBar(title: Text('Monero Light Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(
              'Restore Wallet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Input your Monero seed below. We will check common formats.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Seed',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) {
                  setState(() {
                    _mnemonic = text;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Restore Height',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) {
                  setState(() {
                    _restoreHeight = int.parse(text);
                  });
                },
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => print("hello"),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await wallet.restoreFromMnemonic(_mnemonic, _restoreHeight);
                    Navigator.pushNamed(context, '/wallet_home');
                  },
                  child: const Text('Restore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
