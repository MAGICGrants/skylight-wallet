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
  List<String> _seed = [];

  @override
  void initState() {
    super.initState();
    _createWallet();
  }

  Future<void> _createWallet() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final seed = await wallet.create();

    setState(() {
      _seed = seed.split(' ');
    });
  }

  void _continue() async {
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
                children: _seed.map((word) {
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
