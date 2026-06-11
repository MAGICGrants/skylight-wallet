import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/coin_home.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:skylight_wallet/widgets/connection_settings_form.dart';

class ConnectionSetupScreenArgs {
  final String coinSymbol;

  ConnectionSetupScreenArgs({required this.coinSymbol});
}

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  bool? _wasConfigured;

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ConnectionSetupScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? 'XMR';
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(coinSymbol);
    final connectionTypeName = wallet?.connectionTypeName ?? 'server';

    _wasConfigured ??= wallet?.connectionAddress.isNotEmpty ?? false;

    void onSaved() {
      unawaited(manager.getWallet(coinSymbol)?.load());

      if (_wasConfigured == true) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/coin_home',
          arguments: CoinHomeScreenArgs(coinSymbol: coinSymbol),
        );
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
                    Text(
                      i18n.connectionSetupTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      i18n.connectionSetupDescription(connectionTypeName),
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
