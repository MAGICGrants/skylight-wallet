import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/screens/create_wallet.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:provider/provider.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> {
  List<String> _seed = [];
  int _restoreHeight = 0;

  @override
  void initState() {
    super.initState();
    _createWallet();
  }

  Future<void> _createWallet() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);

    try {
      final (seed, restoreHeight) = await wallet.create();
      wallet.load();

      setState(() {
        _seed = seed.split(' ');
        _restoreHeight = restoreHeight;
      });
    } catch (error) {
      var errorMsg = 'Sorry, something went wrong.';

      if (error.toString().contains('failedToLoadHeight')) {
        errorMsg = 'Check your internet connection.';
      } else {
        log(LogLevel.error, error.toString());
      }

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/create_wallet',
          arguments: CreateWalletScreenArgs(toastMessage: errorMsg),
        );
      }
    }
  }

  void _continue() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/lws_details',
      (Route<dynamic> route) => false,
      arguments: _restoreHeight,
    );
    Provider.of<FiatRateModel>(context, listen: false).startService();
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
                  if (_seed.isEmpty || _restoreHeight == 0) CircularProgressIndicator(),
                  if (_seed.isNotEmpty && _restoreHeight > 0)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: _seed.map((word) {
                        return Chip(label: Text(word));
                      }).toList(),
                    ),
                  if (_seed.isNotEmpty && _restoreHeight > 0)
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
