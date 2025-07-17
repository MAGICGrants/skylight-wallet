import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  String _destinationAddress = '';
  double _amount = 0;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletModel>();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text('Send', style: Theme.of(context).textTheme.headlineMedium),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Address',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) {
                  setState(() {
                    _destinationAddress = text;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?')),
                ],
                decoration: InputDecoration(
                  hintText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) {
                  setState(() {
                    _amount = double.parse(text);
                  });
                },
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/wallet_home'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    wallet.send(_destinationAddress, _amount);
                    Navigator.pushNamed(context, '/wallet_home');
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
