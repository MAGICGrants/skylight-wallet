import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Monero Light Wallet')),
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
                  onPressed: () =>
                      Navigator.pushNamed(context, '/restore_warning'),
                  child: Text(i18n.createWalletRestoreExistingButton),
                ),
                ElevatedButton(
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
