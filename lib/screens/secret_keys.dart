import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';

class SecretKeysScreen extends StatefulWidget {
  const SecretKeysScreen({super.key});

  @override
  State<SecretKeysScreen> createState() => _SecretKeysScreenState();
}

class _SecretKeysScreenState extends State<SecretKeysScreen> with SecureScreenMixin {
  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final legacySeed = wallet.w2Wallet!.seed(seedOffset: '');
    final polyseed = wallet.w2Wallet!.getPolyseed(passphrase: '');
    final secretSpendKey = wallet.w2Wallet!.secretSpendKey();
    final publicSpendKey = wallet.w2Wallet!.publicSpendKey();
    final publicViewKey = wallet.w2Wallet!.publicViewKey();

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
                    onPressed: () => SecureClipboard.copy(legacySeed),
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
                    onPressed: () => SecureClipboard.copy(polyseed),
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
                    onPressed: () => SecureClipboard.copy(publicSpendKey),
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
                    onPressed: () => SecureClipboard.copy(secretSpendKey),
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
                    onPressed: () => SecureClipboard.copy(publicViewKey),
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
