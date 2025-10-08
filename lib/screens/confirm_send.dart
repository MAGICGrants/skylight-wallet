import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:monero/src/monero.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/fiat_rate_model.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/util/formatting.dart';
import 'package:monero_light_wallet/util/logging.dart';
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
  List<String> _destinationAddressSliced = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _loadTxDetails();
  }

  void _loadTxDetails() {
    final args =
        ModalRoute.of(context)!.settings.arguments as ConfirmSendScreenArgs?;

    if (args == null) {
      throw Exception('Args missing');
    }

    setState(() {
      _tx = args.tx;
      _amount = doubleAmountFromInt(args.tx.amount());
      _fee = doubleAmountFromInt(args.tx.fee());
      _destinationOpenAlias = args.destinationOpenAlias;
      _destinationAddress = args.destinationAddress;
      _destinationAddressSliced = _sliceAddress(args.destinationAddress);
    });
  }

  List<String> _sliceAddress(String address) {
    List<String> result = [];

    for (int i = 0; i < address.length; i += 5) {
      // Get the substring of the next 5 characters
      String substring = address.substring(
        i,
        i + 5 > address.length ? address.length : i + 5,
      );
      result.add(substring);
    }

    return result;
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
      var errorMsg = error.toString().replaceFirst('FormatException: ', '');

      if (error.toString().contains('HTTP error code 500')) {
        errorMsg =
            'Failed to send transaction. You might have insufficient unlocked balance.';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (error) {
      log(LogLevel.error, error.toString());
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
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = fiatRate.fiatCode == 'EUR' ? '€' : '\$';
    final amountFiat = fiatRate.rate is double
        ? _amount * fiatRate.rate!
        : null;
    final networkFeeFiat = fiatRate.rate is double
        ? _fee * fiatRate.rate!
        : null;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                i18n.confirmSendTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Text(
              i18n.confirmSendDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.amount,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_amount.toStringAsFixed(12)} XMR',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (amountFiat is double)
                      Text('$fiatSymbol${amountFiat.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.networkFee,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_fee.toStringAsFixed(12)} XMR',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (networkFeeFiat is double)
                      Text('$fiatSymbol${networkFeeFiat.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
            if (_destinationOpenAlias is String)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OpenAlias',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_destinationOpenAlias!),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.address,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                Expanded(
                  child: Container(
                    margin: EdgeInsetsGeometry.only(left: 40),
                    child: Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.end,
                      children: _destinationAddressSliced
                          .asMap()
                          .entries
                          .map(
                            (item) => Text(
                              item.value,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                // highlight start and end slices of address
                                fontWeight:
                                    item.key == 0 ||
                                        item.key ==
                                            _destinationAddressSliced.length - 1
                                    ? FontWeight.w700
                                    : FontWeight.w300,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
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
