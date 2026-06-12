import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/create_wallet.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';
import 'package:skylight_wallet/widgets/loading_button.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> {
  List<String> _seed = [];
  DateTime? _restoreDate;
  String? _mnemonic;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final result = Provider.of<WalletManager>(context, listen: false).generateSeed();
    _mnemonic = result.mnemonic;
    _seed = result.mnemonic.split(' ');
    _restoreDate = result.restoreDate;
  }

  Future<void> _continue() async {
    if (_isCreating || _mnemonic == null || _restoreDate == null) return;

    setState(() {
      _isCreating = true;
    });

    final manager = Provider.of<WalletManager>(context, listen: false);

    try {
      await manager.restoreAll(bip39Mnemonic: _mnemonic!, restoreDate: _restoreDate!);
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        Navigator.pushNamed(
          context,
          '/create_wallet',
          arguments: CreateWalletScreenArgs(toastMessage: 'Sorry, something went wrong.'),
        );
      }
      return;
    }

    manager.syncInBackground();

    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
    }
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: _seed.map((word) => Chip(label: Text(word))).toList(),
                  ),
                  if (_restoreDate != null)
                    Text(
                      '${i18n.restoreWalletRestoreDateLabel}: ${MaterialLocalizations.of(context).formatCompactDate(_restoreDate!)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  LoadingButton(
                    isLoading: _isCreating,
                    onPressed: _continue,
                    label: i18n.generateSeedContinueButton,
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
