import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/coin_home.dart';
import 'package:skylight_wallet/util/formatting.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/wallets/crypto_wallet.dart';
import 'package:skylight_wallet/wallets/wallet_manager.dart';

class ConfirmSendScreenArgs {
  final String coinSymbol;
  final PendingTransaction tx;
  final String destinationAddress;
  final String? destinationOpenAlias;
  final String? destinationContactName;

  ConfirmSendScreenArgs({
    required this.coinSymbol,
    required this.tx,
    required this.destinationAddress,
    this.destinationOpenAlias,
    this.destinationContactName,
  });
}

class ConfirmSendScreen extends StatefulWidget {
  const ConfirmSendScreen({super.key});

  @override
  State<ConfirmSendScreen> createState() => _ConfirmSendScreenState();
}

class _ConfirmSendScreenState extends State<ConfirmSendScreen> {
  bool _isLoading = false;
  PendingTransaction? _tx;
  double _amount = 0.0;
  double _fee = 0.0;
  String? _destinationOpenAlias;
  String _destinationAddress = '';
  String? _destinationContactName;
  String _coinSymbol = 'XMR';
  bool _argsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    _loadTxDetails();
  }

  void _loadTxDetails() {
    final args = ModalRoute.of(context)!.settings.arguments as ConfirmSendScreenArgs?;

    if (args == null) {
      throw Exception('Args missing');
    }

    setState(() {
      _coinSymbol = args.coinSymbol;
      _tx = args.tx;
      _amount = args.tx.amount;
      _fee = args.tx.fee;
      _destinationOpenAlias = args.destinationOpenAlias;
      _destinationAddress = args.destinationAddress;
      _destinationContactName = args.destinationContactName;
    });
  }

  Widget _buildVerifiableAddress(String address) {
    final parts = addressDisplayParts(address);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 200),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: 'monospace', fontSize: 14),
          children: [
            TextSpan(text: parts.prefix, style: TextStyle(fontWeight: FontWeight.w700)),
            if (parts.middle.isNotEmpty)
              TextSpan(text: parts.middle, style: TextStyle(fontWeight: FontWeight.w300)),
            TextSpan(text: parts.suffix, style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        textAlign: TextAlign.end,
      ),
    );
  }

  Future<void> _confirmSend() async {
    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(_coinSymbol);

    if (_tx == null || wallet == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await wallet.commitTx(_tx!, _destinationAddress);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/coin_home',
          // remove until the coin home screen is reached
          (route) => route.settings.name == '/wallet_home',
          arguments: CoinHomeScreenArgs(coinSymbol: _coinSymbol, showTxSuccessToast: true),
        );
      }
    } on FormatException catch (error) {
      var errorMsg = error.toString().replaceFirst('FormatException: ', '');

      if (error.toString().contains('HTTP error code 500')) {
        errorMsg = 'Failed to send transaction. You might have insufficient unlocked balance.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = fiatRate.fiatCode == 'EUR' ? '€' : '\$';
    final wallet = context.watch<WalletManager>().getWallet(_coinSymbol);
    final decimals = wallet?.decimals ?? 12;
    final coinSymbol = wallet?.coinSymbol ?? _coinSymbol;
    final coinRate = fiatRate.rateFor(coinSymbol, isTestnet: wallet?.isTestnet);
    final amountFiat = wallet?.isTestnet != true && coinRate != null ? _amount * coinRate : null;
    final networkFeeFiat = wallet?.isTestnet != true && coinRate != null ? _fee * coinRate : null;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 440),
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
                    Text(i18n.amount, style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_amount.toStringAsFixed(decimals)} $coinSymbol',
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
                    Text(i18n.networkFee, style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_fee.toStringAsFixed(decimals)} $coinSymbol',
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
                      Text('OpenAlias', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_destinationOpenAlias!),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n.address, style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 40),
                            child: _buildVerifiableAddress(_destinationAddress),
                          ),
                          if (_destinationContactName is String) Text('($_destinationContactName)'),
                        ],
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _confirmSend,
                  icon: !_isLoading
                      ? Icon(Icons.arrow_outward_rounded)
                      : SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDarkTheme
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.white,
                          ),
                        ),
                  label: Text(i18n.sendSendButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
