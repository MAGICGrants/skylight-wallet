import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/widgets/wallet_navigation_bar.dart';
import 'package:provider/provider.dart';

class KeysScreen extends StatelessWidget {
  const KeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final restoreHeight = wallet.wallet.getRefreshFromBlockHeight();
    final primaryAddress = wallet.getPrimaryAddress();
    final secretSpendKey = wallet.wallet.secretSpendKey();
    final publicSpendKey = wallet.wallet.publicSpendKey();
    final secretViewKey = wallet.wallet.secretViewKey();
    final publicViewKey = wallet.wallet.publicViewKey();

    return Scaffold(
      bottomNavigationBar: WalletNavigationBar(selectedIndex: 1),
      appBar: AppBar(title: Text('Keys')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.keysPrimaryAddress,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          controller: TextEditingController(
                            text: primaryAddress,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: primaryAddress),
                        ),
                        icon: Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.keysRestoreHeight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          controller: TextEditingController(
                            text: restoreHeight.toString(),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: restoreHeight.toString()),
                        ),
                        icon: Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.keysSecretSpendKey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          controller: TextEditingController(
                            text: secretSpendKey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: secretSpendKey),
                        ),
                        icon: Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.keysPublicSpendKey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          controller: TextEditingController(
                            text: publicSpendKey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: publicSpendKey),
                        ),
                        icon: Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.keysSecretViewKey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          controller: TextEditingController(
                            text: secretViewKey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: secretViewKey),
                        ),
                        icon: Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.keysPublicViewKey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          controller: TextEditingController(
                            text: publicViewKey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: publicViewKey),
                        ),
                        icon: Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
