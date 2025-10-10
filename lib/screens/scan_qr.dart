import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/screens/send.dart';
import 'package:provider/provider.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  void _onScannerDetect(BarcodeCapture result) {
    final scanResult = result.barcodes.first.rawValue;
    if (scanResult == null) return;

    _getAddressAndAmountFromScanResult(scanResult);
  }

  void _getAddressAndAmountFromScanResult(String scanResult) {
    final wallet = Provider.of<WalletModel>(context, listen: false);

    String address = '';
    double? amount;
    final uri = Uri.tryParse(scanResult);

    if (uri != null && uri.scheme == 'monero') {
      if (!wallet.w2Wallet!.addressValid(uri.path, 0)) return;

      address = uri.path;

      if (uri.queryParameters.containsKey('tx_amount')) {
        amount = double.tryParse(uri.queryParameters['tx_amount']!);
      }
    } else if (wallet.w2Wallet!.addressValid(scanResult, 0)) {
      address = scanResult;
    } else {
      return;
    }

    final sendScreenArgs = SendScreenArgs(
      destinationAddress: address,
      amount: amount,
    );

    Navigator.pushNamed(context, '/send', arguments: sendScreenArgs);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.scanQrTitle)),
      body: SafeArea(child: MobileScanner(onDetect: _onScannerDetect)),
    );
  }
}
