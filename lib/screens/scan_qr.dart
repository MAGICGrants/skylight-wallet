import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScannerDetect(BarcodeCapture result) {
    if (_hasScanned) return;

    final scanResult = result.barcodes.first.rawValue;
    if (scanResult == null) return;

    _hasScanned = true;
    _controller.stop();
    Navigator.pop(context, scanResult);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.scanQrTitle)),
      body: SafeArea(child: MobileScanner(controller: _controller, onDetect: _onScannerDetect)),
    );
  }
}
