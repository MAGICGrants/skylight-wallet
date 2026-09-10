import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/floating_bob.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _pushHomeIfWalletExists();
  }

  Future<void> _pushHomeIfWalletExists() async {
    if (await openExistingWallet(context) && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return WelcomeView(
      logo: FloatingBob(child: SvgPicture.asset('assets/logo_nobg.svg', width: 132, height: 132)),
      appName: 'Skylight Wallet',
      appNameColor: BrandColors.ink,
      logoBottomGap: BrandSpacing.md,
      description: i18n.welcomeDescription,
      labels: WelcomeLabels(
        getStarted: i18n.welcomeGetStarted,
        agreePrefix: i18n.welcomeAgreePrefix,
        termsLink: i18n.welcomeTermsLink,
        agreeMiddle: i18n.welcomeAgreeMiddle,
        privacyLink: i18n.welcomePrivacyLink,
      ),
      onGetStarted: () => Navigator.pushNamed(context, '/tor_settings'),
      onTerms: () => Navigator.pushNamed(context, '/terms_of_service'),
      onPrivacy: () => Navigator.pushNamed(context, '/privacy_policy'),
    );
  }
}
