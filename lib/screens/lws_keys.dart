import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop: LWS keys as a centered modal (opened from Settings); mobile keeps
/// the full-screen route.
Future<void> showLwsKeysSheet(BuildContext context) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight(ctx)),
      child: const LwsKeysScreen(asModal: true),
    ),
  );
}

class LwsKeysScreen extends StatefulWidget {
  final bool asModal;

  const LwsKeysScreen({super.key, this.asModal = false});

  @override
  State<LwsKeysScreen> createState() => _LwsKeysScreenState();
}

class _LwsKeysScreenState extends State<LwsKeysScreen> with SecureScreenMixin {
  var _restoreHeight = 0;
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
      _secretViewKey = secretViewKey;
    });
  }

  void _copy(String value) {
    if (value.isEmpty) return;
    SecureClipboard.copy(value);
    final i18n = AppLocalizations.of(context)!;
    showCopyToast(context, i18n.copiedToClipboard);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final primaryAddress = appWalletOf(context, listen: true).getPrimaryAddress();

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
      primaryAddress: primaryAddress,
      secretViewKey: _secretViewKey,
      restoreHeight: _restoreHeight.toString(),
      onCopy: _copy,
      asModal: widget.asModal,
      onBack: widget.asModal ? null : () => Navigator.pop(context),
    );
  }
}
