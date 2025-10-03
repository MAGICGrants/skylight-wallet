import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class LwsKeysScreen extends StatefulWidget {
  const LwsKeysScreen({super.key});

  @override
  State<LwsKeysScreen> createState() => _LwsKeysScreenState();
}

class _LwsKeysScreenState extends State<LwsKeysScreen> {
  var _restoreHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadRestoreHeight();
  }

  Future<void> _loadRestoreHeight() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final restoreHeight = await wallet.getRestoreHeight();

    setState(() {
      _restoreHeight = restoreHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletModel>();
    final primaryAddress = wallet.getPrimaryAddress();
    final secretViewKey = wallet.w2Wallet!.secretViewKey();

    return Scaffold(
      appBar: AppBar(title: Text(i18n.lwsKeysTitle)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.lwsKeysPrimaryAddress,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: primaryAddress),
                              ),
                              icon: Icon(Icons.copy),
                            ),
                          ),
                          controller: TextEditingController(
                            text: primaryAddress,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.lwsKeysSecretViewKey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: secretViewKey),
                              ),
                              icon: Icon(Icons.copy),
                            ),
                          ),
                          controller: TextEditingController(
                            text: secretViewKey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: i18n.lwsKeysRestoreHeight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: _restoreHeight.toString()),
                              ),
                              icon: Icon(Icons.copy),
                            ),
                          ),
                          controller: TextEditingController(
                            text: _restoreHeight.toString(),
                          ),
                        ),
                      ),
                    ],
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
