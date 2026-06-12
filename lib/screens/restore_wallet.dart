import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/loading_button.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> {
  final _mnemonicController = TextEditingController();
  final _restoreDateController = TextEditingController();
  DateTime _restoreDate = DateTime.now();
  bool _isLoading = false;
  String? _mnemonicError;

  @override
  void initState() {
    super.initState();
    _restoreDateController.text = _formatDate(_restoreDate);
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _restoreDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _restoreDate,
      firstDate: DateTime(2014, 4),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _restoreDate = picked;
        _restoreDateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _restore() async {
    if (_isLoading) return;

    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);

    setState(() {
      _mnemonicError = null;
    });

    final mnemonic = _mnemonicController.text.trim();

    if (mnemonic.isEmpty) {
      setState(() {
        _mnemonicError = i18n.fieldEmptyError;
      });
      return;
    }

    if (!bip39.validateMnemonic(mnemonic)) {
      setState(() {
        _mnemonicError = i18n.restoreWalletInvalidMnemonic;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await manager.restoreAll(bip39Mnemonic: mnemonic, restoreDate: _restoreDate);
    } catch (error) {
      log(LogLevel.error, error.toString());
      setState(() {
        _isLoading = false;
        _mnemonicError = i18n.unknownError;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    manager.syncInBackground();

    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
    }
  }

  void _onMnemonicChanged(String value) {
    if (_mnemonicError != null) {
      setState(() {
        _mnemonicError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Wallet')),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(i18n.restoreWalletTitle, style: Theme.of(context).textTheme.headlineMedium),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  i18n.restoreWalletDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextFormField(
                  controller: _mnemonicController,
                  onChanged: _onMnemonicChanged,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 3,
                  decoration: InputDecoration(
                    labelText: i18n.restoreWalletSeedLabel,
                    errorText: _mnemonicError,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextFormField(
                  controller: _restoreDateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    labelText: i18n.restoreWalletRestoreDateLabel,
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
              ),
              Row(
                spacing: 20,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.cancel)),
                  LoadingButton(
                    isLoading: _isLoading,
                    onPressed: _restore,
                    label: i18n.restoreWalletRestoreButton,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
