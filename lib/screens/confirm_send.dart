import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:monero/src/monero.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/util/formatting.dart';
import 'package:provider/provider.dart';

class ConfirmSendScreenArgs {
  MoneroPendingTransaction tx;
  String? destinationOpenAlias;
  String destinationAddress;

  ConfirmSendScreenArgs({
    required this.tx,
    required this.destinationAddress,
    this.destinationOpenAlias,
  });
}

class ConfirmSendScreen extends StatefulWidget {
  const ConfirmSendScreen({super.key});

  @override
  State<ConfirmSendScreen> createState() => _ConfirmSendScreenState();
}

class _ConfirmSendScreenState extends State<ConfirmSendScreen> {
  bool _isLoading = false;
  MoneroPendingTransaction? _tx;
  double _amount = 0.0;
  double _fee = 0.0;
  String? _destinationOpenAlias;
  String _destinationAddress = '';

  @override
  void initState() {
    super.initState();
    _loadTxDetails();
  }

  void _loadTxDetails() {
    final args =
        ModalRoute.of(context)!.settings.arguments as ConfirmSendScreenArgs?;

    if (args == null) {
      throw Exception('Args missing');
    }

    setState(() {
      _amount = doubleAmountFromInt(args.tx.amount());
      _fee = doubleAmountFromInt(args.tx.fee());
      _destinationOpenAlias = args.destinationOpenAlias;
      _destinationAddress = args.destinationAddress;
    });
  }

  Future<void> _confirmSend() async {
    final i18n = AppLocalizations.of(context)!;
    final wallet = Provider.of<WalletModel>(context, listen: false);

    if (_tx == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await wallet.commitTx(_tx!, _destinationAddress);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/wallet_home',
          arguments: {'showTxSuccessToast': true},
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('FormatException: ', ''),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.confirmSendTitle)),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text(
              i18n.confirmSendDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(i18n.amount), Text(_amount.toString())],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(i18n.networkFee), Text(_fee.toString())],
            ),
            if (_destinationOpenAlias is String)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('OpenAlias'), Text(_destinationOpenAlias!)],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(i18n.address), Text(_destinationAddress)],
            ),
            ElevatedButton(
              onPressed: _confirmSend,
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
      ),
    );
  }
}
