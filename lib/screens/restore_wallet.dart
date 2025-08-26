import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
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
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();

    return Scaffold(
      appBar: AppBar(title: Text('Monero Light Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(
              i18n.restoreWalletTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                i18n.restoreWalletDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 3,
                decoration: InputDecoration(
                  labelText: i18n.restoreWalletSeedLabel,
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
                  labelText: i18n.restoreWalletRestoreHeightLabel,
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(i18n.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await wallet.restoreFromMnemonic(_mnemonic, _restoreHeight);
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/wallet_home');
                    }
                  },
                  child: Text(i18n.restoreWalletRestoreButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
