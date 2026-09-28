import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class LwsDetailsScreen extends StatefulWidget {
  const LwsDetailsScreen({super.key});

  @override
  State<LwsDetailsScreen> createState() => _LwsDetailsScreenState();
}

class _LwsDetailsScreenState extends State<LwsDetailsScreen> with SecureScreenMixin {
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
    final restoreHeight = ModalRoute.of(context)!.settings.arguments as int;

    final labels = LwsKeysLabels(
      title: i18n.lwsDetailsTitle,
      description: i18n.lwsDetailsDescription,
      primaryAddressLabel: i18n.lwsDetailsPrimaryAddressLabel,
      viewKeyLabel: i18n.lwsDetailsSecretViewKeyLabel,
      restoreHeightLabel: i18n.lwsDetailsRestoreHeightLabel,
      reveal: i18n.generateSeedReveal,
      warning: i18n.lwsKeysWarning,
    );

    void goHome() => Navigator.pushNamedAndRemoveUntil(
      context,
      '/wallet_home',
      (Route<dynamic> route) => false,
    );

    // Desktop: an unnumbered onboarding step — the two-pane chrome carries the
    // title/description/warning, the content slot shows just the value cards.
    if (isDesktop) {
      return DesktopOnboardingScaffold(
        showSteps: false,
        logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
        title: i18n.lwsDetailsTitle,
        description: i18n.lwsDetailsDescription,
        step: 0,
        totalSteps: 0,
        continueLabel: i18n.continueText,
        onContinue: goHome,
        notes: [OnboardingNote(Icons.visibility_off_outlined, i18n.lwsKeysWarning)],
        content: LwsKeysView(
          fieldsOnly: true,
          labels: labels,
          primaryAddress: primaryAddress,
          secretViewKey: _secretViewKey,
          restoreHeight: restoreHeight.toString(),
          onCopy: _copy,
        ),
      );
    }

    return LwsKeysView(
      largeTitle: true,
      labels: labels,
      primaryAddress: primaryAddress,
      secretViewKey: _secretViewKey,
      restoreHeight: restoreHeight.toString(),
      onCopy: _copy,
      footer: BrandButton(label: i18n.continueText, onPressed: goHome),
    );
  }
}
