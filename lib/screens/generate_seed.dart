import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/create_wallet.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';

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
    final manager = Provider.of<WalletManager>(context, listen: false);

    try {
      final result = await manager.createFromNewSeed();
      manager.syncInBackground();

      setState(() {
        _seed = result.mnemonic.split(' ');
      });
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/create_wallet',
          arguments: CreateWalletScreenArgs(toastMessage: 'Sorry, something went wrong.'),
        );
      }
    }
  }

  void _continue() {
    final manager = Provider.of<WalletManager>(context, listen: false);
    Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
    Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: EdgeInsetsGeometry.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 20,
                children: [
                  Text(i18n.generateSeedTitle, style: Theme.of(context).textTheme.headlineMedium),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      i18n.generateSeedDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  if (_seed.isEmpty) CircularProgressIndicator(),
                  if (_seed.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: _seed.map((word) => Chip(label: Text(word))).toList(),
                    ),
                  if (_seed.isNotEmpty)
                    FilledButton(
                      onPressed: _continue,
                      child: Text(i18n.generateSeedContinueButton),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
