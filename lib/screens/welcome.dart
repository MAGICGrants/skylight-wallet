import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/theme_language_sheets.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

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
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (await manager.hasAnyExistingWallet()) {
      await manager.openAll();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: BrandSpacing.sm),
              // Language is reachable here because this is the one screen with
              // no route to Settings — a reader who can't read it must be able
              // to switch before anything else. Row (not BrandScreenHeader) so
              // the centred logo below keeps its intrinsic size.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconCircleButton(
                    icon: Icons.language,
                    onPressed: () => showLanguageSheet(context),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              SvgPicture.asset('assets/spice-mark.svg', width: 96, height: 96),
              const SizedBox(height: BrandSpacing.xl),
              Text(
                'Spice Wallet',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: BrandColors.cinnamonDeep,
                ),
              ),
              const SizedBox(height: BrandSpacing.md),
              Text(
                i18n.welcomeDescription,
                textAlign: TextAlign.center,
                style: BrandText.bodyMuted,
              ),
              const Spacer(flex: 4),
              BrandButton(
                label: i18n.welcomeGetStarted,
                onPressed: () => Navigator.pushNamed(context, '/tor_settings'),
              ),
              const SizedBox(height: BrandSpacing.lg),
              const _TermsLine(),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsLine extends StatelessWidget {
  const _TermsLine();

  TapGestureRecognizer _to(BuildContext context, String route) =>
      TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, route);

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final link = BrandText.caption.copyWith(
      color: BrandColors.cinnamonDeep,
      fontWeight: FontWeight.w500,
    );
    return Text.rich(
      TextSpan(
        style: BrandText.caption,
        children: [
          TextSpan(text: i18n.welcomeAgreePrefix),
          TextSpan(
            text: i18n.welcomeTermsLink,
            style: link,
            recognizer: _to(context, '/terms_of_service'),
          ),
          TextSpan(text: i18n.welcomeAgreeMiddle),
          TextSpan(
            text: i18n.welcomePrivacyLink,
            style: link,
            recognizer: _to(context, '/privacy_policy'),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
