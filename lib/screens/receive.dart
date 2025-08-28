import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:monero_light_wallet/services/shared_preferences_service.dart';
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
  bool _showReceiveSubaddress = false;

  @override
  void initState() {
    super.initState();

    _loadShowReceiveSubaddress();

    final wallet = Provider.of<WalletModel>(context, listen: false);
    _address = wallet.getPrimaryAddress();
  }

  Future<void> _loadShowReceiveSubaddress() async {
    final showReceiveSubaddress =
        await SharedPreferencesService.get<bool>(
          SharedPreferencesKeys.showReceiveSubaddress,
        ) ??
        false;

    setState(() {
      _showReceiveSubaddress = showReceiveSubaddress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    Future<void> setUsingSubaddress(bool value) async {
      final wallet = Provider.of<WalletModel>(context, listen: false);

      await SharedPreferencesService.set(
        SharedPreferencesKeys.showReceiveSubaddress,
        value,
      );

      final subddress = await wallet.getUnusedSubaddress();

      if (value) {
        setState(() {
          _showReceiveSubaddress = true;
          _address = subddress;
        });
      } else {
        setState(() {
          _showReceiveSubaddress = false;
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
            if (_showReceiveSubaddress)
              Text(
                i18n.receiveSubaddressWarn,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            if (!_showReceiveSubaddress)
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
                if (!_showReceiveSubaddress)
                  TextButton(
                    onPressed: () => setUsingSubaddress(true),
                    child: Text(i18n.receiveShowSubaddressButton),
                  ),
                if (_showReceiveSubaddress)
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
