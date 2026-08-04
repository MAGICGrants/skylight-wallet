import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';

class CreateWalletScreenArgs {
  String toastMessage;

  CreateWalletScreenArgs({required this.toastMessage});
}

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  @override
  void initState() {
    super.initState();
    _showErrorIfNeeded();
  }

  void _showErrorIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as CreateWalletScreenArgs?;

      if (args != null && args.toastMessage != '') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(args.toastMessage)));
      }
    });
  }

  /// The warning is about the LWS server learning your whole transaction
  /// history from the view key. A full node scans locally and is told nothing,
  /// so restoring against one goes straight to the seed form.
  void _restoreExisting() {
    final wallet = Provider.of<WalletModel>(context, listen: false);

    Navigator.pushNamed(
      context,
      wallet.isNodeMode ? '/restore_wallet' : '/restore_warning',
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Monero Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(
              i18n.createWalletTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                i18n.createWalletDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _restoreExisting,
                  child: Text(i18n.createWalletRestoreExistingButton),
                ),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/generate_seed',
                    (Route<dynamic> route) => false,
                  ),
                  child: Text(i18n.createWalletCreateNewButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
