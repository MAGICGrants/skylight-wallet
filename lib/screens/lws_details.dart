import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';

class LwsDetailsScreen extends StatefulWidget {
  const LwsDetailsScreen({super.key});

  @override
  State<LwsDetailsScreen> createState() => _LwsDetailsScreenState();
}

class _LwsDetailsScreenState extends State<LwsDetailsScreen> {
  String _secretViewKey = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await appWalletOf(context).readSecretViewKey();
    if (!mounted) return;
    setState(() => _secretViewKey = key);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final primaryAddress = appWalletOf(context).getPrimaryAddress();
    final secretViewKey = _secretViewKey;
    final restoreHeight = ModalRoute.of(context)!.settings.arguments as int;

    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                Text(i18n.lwsDetailsTitle, style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  i18n.lwsDetailsDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: i18n.lwsDetailsPrimaryAddressLabel,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        controller: TextEditingController(text: primaryAddress),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: primaryAddress)),
                      icon: Icon(Icons.copy),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: i18n.lwsDetailsSecretViewKeyLabel,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        controller: TextEditingController(text: secretViewKey),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: secretViewKey)),
                      icon: Icon(Icons.copy),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: i18n.lwsDetailsRestoreHeightLabel,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        controller: TextEditingController(text: restoreHeight.toString()),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: restoreHeight.toString())),
                      icon: Icon(Icons.copy),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/wallet_home',
                    (Route<dynamic> route) => false,
                  ),
                  child: Text(i18n.continueText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
