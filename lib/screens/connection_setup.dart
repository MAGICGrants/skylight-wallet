import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';

class ConnectionSetupScreenArgs {
  final String coinSymbol;
  final String? successRoute;

  ConnectionSetupScreenArgs({required this.coinSymbol, this.successRoute});
}

class ConnectionSetupScreen extends StatelessWidget {
  const ConnectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ConnectionSetupScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? 'XMR';

    void onSaved() {
      final manager = Provider.of<WalletManager>(context, listen: false);
      manager.getWallet(coinSymbol)?.load();

      final route = args?.successRoute;
      if (route != null) {
        Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
      } else {
        Navigator.pop(context);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Wallet')),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                Column(
                  spacing: 10,
                  children: [
                    Text(i18n.lwsSetupTitle, style: Theme.of(context).textTheme.headlineMedium),
                    Text(
                      i18n.lwsSetupDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                ConnectionSettingsForm(
                  coinSymbol: coinSymbol,
                  saveButtonLabel: i18n.lwsSetupContinueButton,
                  onSaved: onSaved,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
