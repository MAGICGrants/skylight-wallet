import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletModel>();
    final address = wallet.getAddress();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: QrImageView(data: address),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: GestureDetector(
                child: Text(
                  address,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: address)),
              icon: Icon(Icons.share),
              label: Text('Share'),
            ),
          ],
        ),
      ),
    );
  }
}
