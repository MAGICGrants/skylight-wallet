import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

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

  void _copy(String value, {required bool sensitive}) {
    if (value.isEmpty) return;
    SecureClipboard.copy(value);
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return LwsKeysView(
      labels: LwsKeysLabels(
        title: i18n.lwsKeysTitle,
        description: i18n.lwsDetailsDescription,
        primaryAddressLabel: i18n.lwsKeysPrimaryAddress,
        viewKeyLabel: i18n.lwsKeysSecretViewKey,
        restoreHeightLabel: i18n.lwsKeysRestoreHeight,
        reveal: i18n.generateSeedReveal,
        warning: i18n.lwsKeysWarning,
      ),
      primaryAddress: _primaryAddress,
      secretViewKey: _secretViewKey,
      restoreHeight: _restoreHeight.toString(),
      onCopy: _copy,
      onBack: () => Navigator.pop(context),
    );
  }
}
