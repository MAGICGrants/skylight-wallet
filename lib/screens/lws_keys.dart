import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallets/coins/monero/monero_wallet.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';

/// Shows the Monero wallet's LWS details (primary address, secret view key,
/// restore height) so the user can whitelist the wallet on a light-wallet
/// server. Read-only with copy buttons.
class LwsKeysScreen extends StatefulWidget {
  const LwsKeysScreen({super.key});

  @override
  State<LwsKeysScreen> createState() => _LwsKeysScreenState();
}

class _LwsKeysScreenState extends State<LwsKeysScreen> with SecureScreenMixin {
  var _restoreHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadRestoreHeight();
  }

  Future<void> _loadRestoreHeight() async {
    final wallet = Provider.of<WalletManager>(context, listen: false).getWallet('XMR');
    if (wallet == null) return;
    final restoreHeight = await wallet.getRestoreHeight();
    if (!mounted) return;
    setState(() => _restoreHeight = restoreHeight);
  }

  Widget _copyField(String label, String value) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        suffixIcon: IconButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          icon: Icon(Icons.copy),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletManager>().getWallet('XMR') as MoneroWallet?;
    final primaryAddress = wallet?.getPrimaryAddress() ?? '';
    final secretViewKey = wallet?.w2Wallet?.secretViewKey() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(i18n.lwsKeysTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Text(
                    i18n.lwsDetailsDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  _copyField(i18n.lwsKeysPrimaryAddress, primaryAddress),
                  _copyField(i18n.lwsKeysSecretViewKey, secretViewKey),
                  _copyField(i18n.lwsKeysRestoreHeight, _restoreHeight.toString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
