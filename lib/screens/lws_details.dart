import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

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

  void _copy(String value, {required bool sensitive}) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final primaryAddress = appWalletOf(context).getPrimaryAddress();
    final restoreHeight = ModalRoute.of(context)!.settings.arguments as int;

    return LwsKeysView(
      largeTitle: true,
      labels: LwsKeysLabels(
        title: i18n.lwsDetailsTitle,
        description: i18n.lwsDetailsDescription,
        primaryAddressLabel: i18n.lwsDetailsPrimaryAddressLabel,
        viewKeyLabel: i18n.lwsDetailsSecretViewKeyLabel,
        restoreHeightLabel: i18n.lwsDetailsRestoreHeightLabel,
        reveal: i18n.generateSeedReveal,
        warning: i18n.lwsKeysWarning,
      ),
      primaryAddress: primaryAddress,
      secretViewKey: _secretViewKey,
      restoreHeight: restoreHeight.toString(),
      onCopy: _copy,
      footer: BrandButton(
        label: i18n.continueText,
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          '/wallet_home',
          (Route<dynamic> route) => false,
        ),
      ),
    );
  }
}
