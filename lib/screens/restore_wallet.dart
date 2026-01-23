import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:polyseed/polyseed.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/util/get_height_by_date.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/models/wallet_model.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> {
  final _mnemonicController = TextEditingController();
  final _restoreHeightController = TextEditingController();
  bool _isPolyseed = false;
  bool _isLoading = false;
  String? _mnemonicError;
  String? _restoreHeightError;

  @override
  void dispose() {
    _mnemonicController.dispose();
    _restoreHeightController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_isLoading) return;

    final i18n = AppLocalizations.of(context)!;

    setState(() {
      _mnemonicError = null;
      _restoreHeightError = null;
    });

    if (_mnemonicController.text.isEmpty) {
      setState(() {
        _mnemonicError = i18n.fieldEmptyError;
      });
      return;
    }

    final wallet = Provider.of<WalletModel>(context, listen: false);

    final mnemonic = _mnemonicController.text.trim();
    final restoreHeight = int.tryParse(_restoreHeightController.text) ?? 0;

    setState(() {
      _isLoading = true;
    });

    try {
      await wallet.restoreFromMnemonic(mnemonic, restoreHeight);
    } on Exception catch (error) {
      final errorMsg = error.toString().replaceFirst('Exception: ', '');

      setState(() {
        _isLoading = false;
      });

      if (errorMsg == 'Invalid mnemonic.') {
        setState(() {
          _mnemonicError = i18n.restoreWalletInvalidMnemonic;
        });

        return;
      } else if (errorMsg != '') {
        setState(() {
          _mnemonicError = i18n.unknownError;
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
      return;
    } catch (error) {
      log(LogLevel.error, error.toString());
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final i18n = AppLocalizations.of(context)!;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
      return;
    }

    setState(() {
      _isLoading = false;
    });

    wallet.load();

    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService();
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
    }
  }

  Future<void> _calculatePolyseedHeight() async {
    final mnemonic = _mnemonicController.text.trim();

    if (!Polyseed.isValidSeed(mnemonic)) {
      if (_isPolyseed) {
        setState(() {
          _isPolyseed = false;
          _restoreHeightController.text = '';
        });
      }
      return;
    }

    final polyseed = Polyseed.decode(
      mnemonic,
      PolyseedLang.getByPhrase(mnemonic),
      PolyseedCoin.POLYSEED_MONERO,
    );

    final birthday = polyseed.birthday;
    final restoreHeight = getHeightByDate(
      date: DateTime.fromMillisecondsSinceEpoch(birthday * 1000),
    );

    setState(() {
      _isPolyseed = true;
      _restoreHeightController.text = restoreHeight.toString();
    });
  }

  void _onMnemonicChanged(String value) {
    _calculatePolyseedHeight();

    if (_mnemonicError != null) {
      setState(() {
        _mnemonicError = null;
      });
    }
  }

  void _onRestoreHeightChanged(String value) {
    if (_restoreHeightError != null) {
      setState(() {
        _restoreHeightError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Monero Wallet')),
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
                  controller: _restoreHeightController,
                  onChanged: _onRestoreHeightChanged,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: i18n.restoreWalletRestoreHeightLabel,
                    errorText: _restoreHeightError,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Row(
                spacing: 20,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n.cancel)),
                  FilledButton.icon(
                    onPressed: _restore,
                    label: Text(i18n.restoreWalletRestoreButton),
                    icon: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDarkTheme
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Colors.white,
                            ),
                          )
                        : null,
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
