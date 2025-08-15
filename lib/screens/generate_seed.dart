import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:provider/provider.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> {
  late List<String> seed;

  @override
  void initState() {
    super.initState();
    final wallet = Provider.of<WalletModel>(context, listen: false);
    seed = wallet.generatePolyseed().split(' ');
  }

  void _continue() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    wallet.connectToDaemon();

    await wallet.restoreFromMnemonic(
      seed.join(' '),
      await wallet.getCurrentHeight() - 1000,
    );

    wallet.store();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/wallet_home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsetsGeometry.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(
                i18n.generateSeedTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  i18n.generateSeedDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: seed.map((word) {
                  return Chip(label: Text(word));
                }).toList(),
              ),
              ElevatedButton(
                onPressed: _continue,
                child: Text(i18n.generateSeedContinueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
