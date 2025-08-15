import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String _address = '';
  bool _usingSubaddress = false;

  @override
  void initState() {
    super.initState();
    final wallet = Provider.of<WalletModel>(context, listen: false);
    _address = wallet.getPrimaryAddress();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    void setUsingSubaddress(bool value) {
      final wallet = Provider.of<WalletModel>(context, listen: false);

      if (value) {
        setState(() {
          _usingSubaddress = true;
          _address = wallet.getUnusedSubaddress();
        });
      } else {
        setState(() {
          _usingSubaddress = false;
          _address = wallet.getPrimaryAddress();
        });
      }
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: QrImageView(data: _address),
            ),
            if (_usingSubaddress)
              Text(
                i18n.receiveSubaddressWarn,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            if (!_usingSubaddress)
              Text(
                i18n.receivePrimaryAddressWarn,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: GestureDetector(
                child: Text(
                  _address,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _address));
                },
              ),
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
                if (!_usingSubaddress)
                  TextButton(
                    onPressed: () => setUsingSubaddress(true),
                    child: Text(i18n.receiveShowSubaddressButton),
                  ),
                if (_usingSubaddress)
                  TextButton(
                    onPressed: () => setUsingSubaddress(false),
                    child: Text(i18n.receiveShowPrimaryAddressButton),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
