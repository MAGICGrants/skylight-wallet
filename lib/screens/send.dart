import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/screens/confirm_send.dart';
import 'package:monero_light_wallet/widgets/monero_amount.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class SendScreenArgs {
  String destinationAddress;
  double? amount;

  SendScreenArgs({required this.destinationAddress, this.amount});
}

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

  @override
  void dispose() {
    _destinationAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _loadFormFromArgs();
  }

  void _loadFormFromArgs() {
    final args = ModalRoute.of(context)!.settings.arguments as SendScreenArgs?;

    if (args != null) {
      _destinationAddressController.text = args.destinationAddress;
      _amountController.text = args.amount != null
          ? args.amount.toString()
          : '';
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data != null) {
      _destinationAddressController.text = data.text ?? '';
    }
  }

  Future<void> _send() async {
    final amount = double.parse(_amountController.text);

    final i18n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _destinationAddressError = '';
      _amountError = '';
    });

    final unresolvedDestinationAddress = _destinationAddressController.text;
    String? destinationOpenAlias;
    String destinationAddress = '';

    final wallet = Provider.of<WalletModel>(context, listen: false);
    final domainRegex = RegExp(
      r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$',
    );

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      // check for openalias
      destinationAddress = wallet.resolveOpenAlias(
        unresolvedDestinationAddress,
      );

      if (destinationAddress == '') {
        setState(() {
          _destinationAddressError = i18n.sendOpenAliasResolveError;
          _isLoading = false;
        });
        return;
      }

      destinationOpenAlias = unresolvedDestinationAddress;
    } else if (wallet.w2Wallet!.addressValid(unresolvedDestinationAddress, 0)) {
      // check for address
      destinationAddress = unresolvedDestinationAddress;
    } else {
      setState(() {
        _destinationAddressError = i18n.sendInvalidAddressError;
        _isLoading = false;
      });
      return;
    }

    if (amount > (wallet.unlockedBalance ?? 0)) {
      setState(() {
        _amountError = i18n.sendInsufficientBalanceError;
        _isLoading = false;
      });
      return;
    }

    try {
      final tx = await wallet.createTx(destinationAddress, amount, _isSweepAll);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/confirm_send',
          arguments: ConfirmSendScreenArgs(
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
          ),
        );
      }
    } catch (error) {
      if (error.toString().contains('Unlocked funds too low')) {
        if (wallet.unlockedBalance! > amount) {
          setState(() {
            _amountError = i18n.sendInsufficientBalanceToCoverFeeError;
          });
        } else {
          setState(() {
            _amountError = i18n.sendInsufficientBalanceError;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _setBalanceAsSendAmount() {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    _amountController.text = (wallet.unlockedBalance ?? 0).toString();

    setState(() {
      _isSweepAll = true;
    });
  }

  void _onSendAmountChanged(double amount) {
    final wallet = Provider.of<WalletModel>(context, listen: false);

    if (amount == wallet.unlockedBalance! && !_isSweepAll) {
      setState(() {
        _isSweepAll = true;
      });
    }

    if (amount != wallet.unlockedBalance! && _isSweepAll) {
      setState(() {
        _isSweepAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.sendTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              // Text(
              //   i18n.sendTitle,
              //   style: Theme.of(context).textTheme.headlineMedium,
              // ),
              TextField(
                controller: _destinationAddressController,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: i18n.address,
                  border: OutlineInputBorder(),
                  errorText: _destinationAddressError != ''
                      ? _destinationAddressError
                      : null,
                  suffixIcon: Row(
                    spacing: 0,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _pasteAddressFromClipboard,
                        icon: Icon(Icons.paste),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/scan_qr'),
                        icon: Icon(Icons.qr_code),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                spacing: 10,
                children: [
                  TextField(
                    controller: _amountController,
                    onChanged: (value) =>
                        _onSendAmountChanged(double.parse(value)),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+(\.\d*)?'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: i18n.amount,
                      border: OutlineInputBorder(),
                      errorText: _amountError != '' ? _amountError : null,
                      suffixIcon: TextButton(
                        onPressed: _setBalanceAsSendAmount,
                        child: Text('Max'),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Spacer(),
                      GestureDetector(
                        onTap: _setBalanceAsSendAmount,
                        child: Row(
                          spacing: 6,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/monero.svg',
                              width: 18,
                              height: 18,
                            ),
                            MoneroAmount(
                              amount: wallet.unlockedBalance ?? 0,
                              maxFontSize: 18,
                            ),
                          ],
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
