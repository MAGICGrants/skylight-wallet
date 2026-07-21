import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/wallets/wallet_manager.dart';
import 'package:spice_wallet/widgets/connection_settings_form.dart';

class ExplorerSetupScreenArgs {
  final String coinSymbol;

  ExplorerSetupScreenArgs({required this.coinSymbol});
}

/// Sets up the optional Blockscout explorer (its own server, Tor/SSL, and
/// test) — separate from the node connection. Used for transaction history.
class ExplorerSetupScreen extends StatelessWidget {
  const ExplorerSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ExplorerSetupScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? '';
    final manager = Provider.of<WalletManager>(context);
    final wallet = manager.getWallet(coinSymbol);

    void onSaved() {
      // Refresh history through the newly-configured explorer.
      unawaited(wallet?.loadTxHistory());
      Navigator.pop(context);
    }

    void onRemove() {
      // Disable the explorer: clear its config, fall back to local history.
      wallet?.setExplorerConnection(address: '', proxyPort: '', useTor: false, useSsl: false);
      unawaited(wallet?.persistExplorerConnection());
      unawaited(wallet?.loadTxHistory());
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(i18n.explorerRemovedMessage)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(wallet?.coinName ?? 'Spice Wallet')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 500),
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20,
                  children: [
                    Text(
                      i18n.explorerSetupTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      i18n.explorerSetupDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    ConnectionSettingsForm(
                      coinSymbol: coinSymbol,
                      target: ConnectionTarget.explorer,
                      saveButtonLabel: i18n.save,
                      onSaved: onSaved,
                    ),
                    if (wallet?.explorerAddress.isNotEmpty ?? false)
                      TextButton.icon(
                        onPressed: onRemove,
                        icon: Icon(Icons.delete),
                        label: Text(i18n.explorerRemoveButton),
                        style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
