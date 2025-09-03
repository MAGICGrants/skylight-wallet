import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  final _destinationAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '');
  bool _isSweepAll = false;

  String _destinationAddressError = '';
  String _amountError = '';

  Future<void> _send() async {
    final amount = double.parse(_amountController.text);

    final i18n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _destinationAddressError = '';
      _amountError = '';
    });

    final destinationAddress = _destinationAddressController.text;
    String resolvedDestinationAddress = '';

    final wallet = Provider.of<WalletModel>(context, listen: false);
    final domainRegex = RegExp(
      r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$',
    );

    if (domainRegex.hasMatch(destinationAddress)) {
      // check for openalias
      resolvedDestinationAddress = wallet.resolveOpenAlias(destinationAddress);

      if (resolvedDestinationAddress == '') {
        setState(() {
          _destinationAddressError = i18n.sendOpenAliasResolveError;
          _isLoading = false;
        });
        return;
      }
    } else if (wallet.wallet.addressValid(destinationAddress, 0)) {
      // check for address
      setState(() {
        resolvedDestinationAddress = destinationAddress;
        _isLoading = false;
      });
    } else {
      setState(() {
        _destinationAddressError = i18n.sendInvalidAddressError;
        _isLoading = false;
      });
      return;
    }

    if (amount > wallet.getTotalBalance()) {
      setState(() {
        _amountError = i18n.sendInsufficientBalanceError;
        _isLoading = false;
      });
      return;
    }

    try {
      await wallet.send(resolvedDestinationAddress, amount, _isSweepAll);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('FormatException: ', '')),
        ),
      );

      setState(() {
        _isLoading = false;
      });

      return;
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unknown error.')));

      setState(() {
        _isLoading = false;
      });

      return;
    }

    setState(() {
      _isLoading = false;
    });

    Navigator.pushNamed(
      context,
      '/wallet_home',
      arguments: {'showTxSuccessToast': true},
    );
  }

  void _setBalanceAsSendAmount() {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final unlockedBalance = wallet.getUnlockedBalance();
    _amountController.text = unlockedBalance.toString();

    setState(() {
      _isSweepAll = true;
    });
  }

  void _onSendAmountChanged() {
    if (_isSweepAll) {
      setState(() {
        _isSweepAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final wallet = context.watch<WalletModel>();
    final unlockedBalance = wallet.getUnlockedBalance();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(
                i18n.sendTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              TextField(
                controller: _destinationAddressController,
                decoration: InputDecoration(
                  labelText: i18n.sendAddressLabel,
                  border: OutlineInputBorder(),
                  errorText: _destinationAddressError != ''
                      ? _destinationAddressError
                      : null,
                ),
              ),
              Column(
                spacing: 10,
                children: [
                  TextField(
                    controller: _amountController,
                    onChanged: (value) => _onSendAmountChanged(),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+(\.\d*)?'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: i18n.sendAmountLabel,
                      border: OutlineInputBorder(),
                      errorText: _amountError != '' ? _amountError : null,
                    ),
                  ),
                  Row(
                    children: [
                      Spacer(),
                      GestureDetector(
                        onTap: _setBalanceAsSendAmount,
                        child: Text(
                          '$unlockedBalance XMR',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                spacing: 20,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(i18n.cancel),
                  ),
                  ElevatedButton(
                    onPressed: _send,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!_isLoading)
                          AnimatedOpacity(
                            opacity: _isLoading ? 0.0 : 1.0,
                            duration: Duration(milliseconds: 300),
                            child: Text(i18n.sendSendButton),
                          ),
                        if (_isLoading)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
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
