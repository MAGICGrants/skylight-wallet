import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';

class LwsKeysScreen extends StatefulWidget {
  const LwsKeysScreen({super.key});

  @override
  State<LwsKeysScreen> createState() => _LwsKeysScreenState();
}

class _LwsKeysScreenState extends State<LwsKeysScreen> with SecureScreenMixin {
  var _restoreHeight = 0;
  var _primaryAddress = '';
  var _secretViewKey = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wallet = appWalletOf(context);
    final restoreHeight = await wallet.getRestoreHeight();
    final secretViewKey = await wallet.readSecretViewKey();
    if (!mounted) return;
    setState(() {
      _restoreHeight = restoreHeight;
      _primaryAddress = wallet.getPrimaryAddress();
      _secretViewKey = secretViewKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final primaryAddress = _primaryAddress;
    final secretViewKey = _secretViewKey;

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
                              onPressed: () => SecureClipboard.copy(primaryAddress),
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
                              onPressed: () => SecureClipboard.copy(secretViewKey),
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
                              onPressed: () => SecureClipboard.copy(_restoreHeight.toString()),
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
