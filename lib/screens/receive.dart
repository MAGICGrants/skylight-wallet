import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
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
  String _address = '';
  bool _showSubaddress = false;
  double _previousBrightness = 0.0;

  @override
  void initState() {
    super.initState();

    final wallet = Provider.of<WalletModel>(context, listen: false);
    _address = wallet.getPrimaryAddress();

    _loadShowReceiveSubaddress();
    _setBrightnessToMax();
  }

  @override
  void dispose() {
    _setBrightnessToNormal();
    super.dispose();
  }

  Future<void> _loadShowReceiveSubaddress() async {
    final showReceiveSubaddress =
        await SharedPreferencesService.get<bool>(
          SharedPreferencesKeys.showReceiveSubaddress,
        ) ??
        false;

    _setShowSubaddress(showReceiveSubaddress);
  }

  Future<void> _setShowSubaddress(bool value) async {
    final wallet = Provider.of<WalletModel>(context, listen: false);

    await SharedPreferencesService.set(
      SharedPreferencesKeys.showReceiveSubaddress,
      value,
    );

    final subddress = await wallet.getUnusedSubaddress();

    if (value) {
      setState(() {
        _showSubaddress = true;
        _address = subddress;
      });
    } else {
      setState(() {
        _showSubaddress = false;
        _address = wallet.getPrimaryAddress();
      });
    }
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

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              QrImageView(data: _address),
              if (_showSubaddress)
                Text(
                  i18n.receiveSubaddressWarn,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              if (!_showSubaddress)
                Text(
                  i18n.receivePrimaryAddressWarn,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              GestureDetector(
                child: Text(
                  _address,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _address));
                },
              ),
              Row(
                spacing: 20,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: _address)),
                    icon: Icon(Icons.share),
                    label: Text(i18n.receiveShareButton),
                  ),
                  if (!_showSubaddress)
                    TextButton(
                      onPressed: () => _setShowSubaddress(true),
                      child: Text(i18n.receiveShowSubaddressButton),
                    ),
                  if (_showSubaddress)
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
