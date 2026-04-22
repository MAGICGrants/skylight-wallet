import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _hasScanned = false;

  void _onScan(Code result) {
    if (_hasScanned) return;

    final text = result.text;
    if (text == null || text.isEmpty) return;

    _hasScanned = true;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.scanQrTitle)),
      body: SafeArea(
        child: ReaderWidget(
          onScan: _onScan,
          showGallery: false,
          cropPercent: 1.0,
          tryHarder: true,
          scanDelay: Duration(milliseconds: 200),
        ),
      ),
    );
  }
}
