import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class SecretKeysScreen extends StatelessWidget {
  const SecretKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final legacySeed = wallet.wallet.seed(seedOffset: '');
    final polyseed = wallet.wallet.getPolyseed(passphrase: '');
    final secretSpendKey = wallet.wallet.secretSpendKey();
    final publicSpendKey = wallet.wallet.publicSpendKey();
    final publicViewKey = wallet.wallet.publicViewKey();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.secretKeysTitle)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '${i18n.secretKeysMnemonic} (legacy)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: legacySeed)),
                    icon: Icon(Icons.copy),
                  ),
                ),
                controller: TextEditingController(text: legacySeed),
              ),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '${i18n.secretKeysMnemonic} (polyseed)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: polyseed)),
                    icon: Icon(Icons.copy),
                  ),
                ),
                controller: TextEditingController(text: polyseed),
              ),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: i18n.secretKeysPublicSpendKey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: publicSpendKey)),
                    icon: Icon(Icons.copy),
                  ),
                ),
                controller: TextEditingController(text: publicSpendKey),
              ),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: i18n.secretKeysSecretSpendKey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: secretSpendKey)),
                    icon: Icon(Icons.copy),
                  ),
                ),
                controller: TextEditingController(text: secretSpendKey),
              ),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: i18n.secretKeysPublicViewKey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: publicViewKey)),
                    icon: Icon(Icons.copy),
                  ),
                ),
                controller: TextEditingController(text: publicViewKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
