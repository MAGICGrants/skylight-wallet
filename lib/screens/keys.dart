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
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.keysPrimaryAddress,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      primaryAddress,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: primaryAddress)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.keysRestoreHeight,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      restoreHeight.toString(),
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () => Clipboard.setData(
                      ClipboardData(text: restoreHeight.toString()),
                    ),
                  ),
                ],
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.keysSecretSpendKey,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      secretSpendKey,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: secretSpendKey)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.keysPublicSpendKey,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      publicSpendKey,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: publicSpendKey)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.keysSecretViewKey,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      secretViewKey,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: secretViewKey)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.keysPublicViewKey,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    child: Text(
                      publicViewKey,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: publicViewKey)),
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
