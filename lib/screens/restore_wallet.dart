import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:polyseed/polyseed.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/util/get_height_by_date.dart';
import 'package:skylight_wallet/util/restore_qr.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/widgets/loading_button.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/models/wallet_model.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> with SecureScreenMixin {
  final _mnemonicController = TextEditingController();
  final _restoreHeightController = TextEditingController();
  final _restoreDateController = TextEditingController();
  DateTime _restoreDate = DateTime.now();
  bool _isPolyseed = false;
  bool _isLoading = false;
  String? _mnemonicError;
  String? _restoreHeightError;

  @override
  void dispose() {
    _mnemonicController.dispose();
    _restoreHeightController.dispose();
    _restoreDateController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.pushNamed(context, '/scan_qr');
    if (result is! String) return;

    final parsed = parseRestoreQr(result);
    if (parsed == null) return;

    setState(() {
      _mnemonicController.text = parsed.seed;
      _mnemonicError = null;

      if (parsed.restoreHeight != null) {
        _restoreHeightController.text = parsed.restoreHeight.toString();
      }
    });

    // No explicit height in the QR — derive it from a polyseed if possible.
    if (parsed.restoreHeight == null) {
      _calculatePolyseedHeight();
    }
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
          _restoreDateController.text = '';
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
    final birthdayDate = DateTime.fromMillisecondsSinceEpoch(birthday * 1000);
    final restoreHeight = getHeightByDate(date: birthdayDate);

    setState(() {
      _isPolyseed = true;
      _restoreDate = birthdayDate;
      _restoreDateController.text = _formatDate(birthdayDate);
      _restoreHeightController.text = restoreHeight.toString();
    });
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
    if (picked == null) return;

    setState(() {
      _restoreDate = picked;
      _restoreDateController.text = _formatDate(picked);
      _restoreHeightController.text = getHeightByDate(date: picked).toString();
      _restoreHeightError = null;
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
                    suffixIcon: (Platform.isAndroid || Platform.isIOS)
                        ? IconButton(
                            icon: Icon(Icons.qr_code),
                            onPressed: _scanQrCode,
                          )
                        : null,
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
