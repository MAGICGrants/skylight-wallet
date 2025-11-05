import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  var _showSubaddress = true;
  var _previousBrightness = 0.0;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid || Platform.isIOS) {
      _setBrightnessToMax();
    }
  }

  @override
  void dispose() {
    _setBrightnessToNormal();
    super.dispose();
  }

  void _setShowSubaddress(bool value) {
    setState(() {
      _showSubaddress = value;
    });
  }

  Future<void> _setBrightnessToMax() async {
    _previousBrightness = await ScreenBrightness().system;
    await ScreenBrightness().setApplicationScreenBrightness(1.0);
  }

  Future<void> _setBrightnessToNormal() async {
    await ScreenBrightness().setApplicationScreenBrightness(
      _previousBrightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final isDarkTheme = brightness == Brightness.dark;
    final wallet = Provider.of<WalletModel>(context);
    final primaryAddress = wallet.getPrimaryAddress();
    final subaddress = wallet.getUnusedSubaddress();
    String? address;

    if (wallet.serverSupportsSubaddresses == false) {
      address = primaryAddress;
    }

    if (wallet.serverSupportsSubaddresses == true) {
      address = _showSubaddress ? subaddress : primaryAddress;
    }

    return Scaffold(
      appBar: AppBar(title: Text(i18n.receiveTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: wallet.serverSupportsSubaddresses == null || address == null
              ? CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 20,
                  children: [
                    QrImageView(
                      data: address,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: isDarkTheme ? Colors.grey[300] : Colors.black,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: isDarkTheme ? Colors.grey[300] : Colors.black,
                      ),
                    ),
                    if (wallet.serverSupportsSubaddresses == false)
                      Text(
                        i18n.receiveServerNoSubaddressesWarn,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    if (!_showSubaddress)
                      Text(
                        i18n.receivePrimaryAddressWarn,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    if (_showSubaddress &&
                        wallet.unusedSubaddressIndexIsSupported == false)
                      Text(
                        i18n.receiveMaxSubaddressesReachedWarn,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    GestureDetector(
                      child: Text(
                        address,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: address!));
                      },
                    ),
                    Row(
                      spacing: 20,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(text: address),
                          ),
                          icon: Icon(Icons.share),
                          label: Text(i18n.receiveShareButton),
                        ),
                        // Only show toggle button if server supports subaddresses
                        if (wallet.serverSupportsSubaddresses == true &&
                            !_showSubaddress)
                          TextButton(
                            onPressed: () => _setShowSubaddress(true),
                            child: Text(i18n.receiveShowSubaddressButton),
                          ),
                        if (wallet.serverSupportsSubaddresses == true &&
                            _showSubaddress)
                          TextButton(
                            onPressed: () => _setShowSubaddress(false),
                            child: Text(i18n.receiveShowPrimaryAddressButton),
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
