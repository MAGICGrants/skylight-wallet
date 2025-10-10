import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:provider/provider.dart';
import 'package:skylight_wallet/models/wallet_model.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> {
  final _mnemonicController = TextEditingController();
  final _restoreHeightController = TextEditingController();
  String? _mnemonicError;

  Future<void> _restore() async {
    setState(() {
      _mnemonicError = null;
    });

    final wallet = Provider.of<WalletModel>(context, listen: false);

    final mnemonic = _mnemonicController.text;
    final restoreHeight = int.parse(_restoreHeightController.text);

    try {
      await wallet.restoreFromMnemonic(mnemonic, restoreHeight);
    } on Exception catch (error) {
      final errorMsg = error.toString().replaceFirst('Exception: ', '');

      if (errorMsg == 'Invalid mnemonic.') {
        setState(() {
          _mnemonicError = errorMsg;
        });

        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
      return;
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        final i18n = AppLocalizations.of(context)!;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
      return;
    }

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/wallet_home',
        (Route<dynamic> route) => false,
      );
    }
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
              i18n.restoreWalletTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
                controller: _restoreHeightController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: i18n.restoreWalletRestoreHeightLabel,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return i18n.fieldEmptyError;
                  }

                  return null;
                },
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(i18n.cancel),
                ),
                FilledButton(
                  onPressed: _restore,
                  child: Text(i18n.restoreWalletRestoreButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
