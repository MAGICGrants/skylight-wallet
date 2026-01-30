import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _hasScanned = false;

  void _onScannerDetect(BarcodeCapture result) {
    if (_hasScanned) return;

    final scanResult = result.barcodes.first.rawValue;
    if (scanResult == null) return;

    _hasScanned = true;
    Navigator.pop(context, scanResult);
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
