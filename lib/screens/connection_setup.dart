import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/connection_settings_form.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

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
  String? _selectedType; // 'lws' / 'node' / '' — reported by the form.

  /// Name shown in "Enter the address of your {type}.", following the form's
  /// segmented selection (Monero LWS ↔ node) rather than the persisted type.
  String _descriptionType(AppLocalizations i18n, CryptoWallet? wallet) {
    switch (_selectedType) {
      case 'lws':
        return i18n.connectionTypeLws;
      case 'node':
        return i18n.connectionTypeNode;
      default:
        return wallet?.connectionTypeName ?? 'server';
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ConnectionSetupScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? 'XMR';
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(coinSymbol);
    final connectionTypeName = _descriptionType(i18n, wallet);

    _wasConfigured ??= wallet?.connectionAddress.isNotEmpty ?? false;

    void onSaved() {
      unawaited(() async {
        // Rebuild first if the server kind changed (e.g. Monero LWS↔node),
        // then refresh against the new connection.
        await manager.applyConnectionChange(coinSymbol);
        await manager.getWallet(coinSymbol)?.load();

        // Tokens (e.g. DAI) piggyback on this chain's connection but hold their
        // own in-memory copy. Re-read it so their balances load now, instead of
        // only after a restart re-hydrates every wallet's persisted connection.
        for (final token in tokensOf(manager, coinSymbol)) {
          await token.loadPersistedConnection();
          await token.load();
        }
      }());

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
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.connectionSetupTitle, style: BrandText.title),
                      const SizedBox(height: 8),
                      Text(
                        _selectedType == 'lws'
                            ? i18n.connectionSetupDescriptionLws(connectionTypeName)
                            : i18n.connectionSetupDescription(connectionTypeName),
                        style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: ConnectionSettingsForm(
                    coinSymbol: coinSymbol,
                    saveButtonLabel: i18n.save,
                    onSaved: onSaved,
                    pinnedSave: true,
                    onConnectionTypeChanged: (type) {
                      if (type != _selectedType) setState(() => _selectedType = type);
                    },
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
