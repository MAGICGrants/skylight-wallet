import 'package:flutter/material.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/util/height.dart';
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
    _loadCurrentHeight();
  }

  Future<void> _createWallet() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final seed = await wallet.create();

    setState(() {
      _seed = seed.split(' ');
    });
  }

  Future<void> _loadCurrentHeight() async {
    final height = await getCurrentBlockchainHeight();
    setState(() {
      _restoreHeight = height;
    });
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
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  i18n.generateSeedDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (_seed.isEmpty || _restoreHeight == 0)
                CircularProgressIndicator(),
              if (_seed.isNotEmpty || _restoreHeight > 0)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  children: _seed.map((word) {
                    return Chip(label: Text(word));
                  }).toList(),
                ),
              if (_seed.isNotEmpty || _restoreHeight > 0)
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/lws_details',
                    arguments: _restoreHeight,
                  ),
                  child: Text(i18n.generateSeedContinueButton),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
