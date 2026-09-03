import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/connection_settings_form.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

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
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(coinSymbol);
    final configured = wallet?.explorerAddress.isNotEmpty ?? false;

    void onSaved() {
      // Refresh history through the newly-configured explorer.
      unawaited(wallet?.loadTxHistory());
      Navigator.pop(context);
    }

    void onRemove() {
      // Disable the explorer: clear its config, fall back to local history.
      wallet?.setExplorerConnection(address: '', proxyPort: '', useTor: false);
      unawaited(wallet?.persistExplorerConnection());
      unawaited(wallet?.loadTxHistory());
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(i18n.explorerRemovedMessage)));
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    onBack: () => Navigator.pop(context),
                    center: CoinBadge(wallet: wallet, fallback: coinSymbol),
                    action: configured
                        ? IconCircleButton(icon: Icons.delete_outline, onPressed: onRemove)
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.explorerSetupTitle, style: BrandText.title),
                      const SizedBox(height: 8),
                      Text(
                        i18n.explorerSetupDescription,
                        style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: ConnectionSettingsForm(
                    coinSymbol: coinSymbol,
                    target: ConnectionTarget.explorer,
                    saveButtonLabel: i18n.save,
                    onSaved: onSaved,
                    pinnedSave: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
