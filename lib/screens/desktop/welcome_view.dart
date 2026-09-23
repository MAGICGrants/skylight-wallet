import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop welcome screen: a centred 540px column (logo, name, description,
/// Get Started, ToS) — the same content as the mobile [WelcomeView], laid out
/// for a desktop window. Every colour is an existing skylightPalette token.
class DesktopWelcomeView extends StatelessWidget {
  final Widget logo;
  final String appName;
  final String description;
  final WelcomeLabels labels;
  final VoidCallback onGetStarted;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const DesktopWelcomeView({
    super.key,
    required this.logo,
    required this.appName,
    required this.description,
    required this.labels,
    required this.onGetStarted,
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: Center(
        child: SizedBox(
          width: 540,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                logo,
                const SizedBox(height: 26),
                Text(
                  appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    fontSize: 15,
                    height: 1.65,
                    color: BrandColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: 320,
                  child: BrandButton(label: labels.getStarted, onPressed: onGetStarted),
                ),
                const SizedBox(height: 16),
                _TermsLine(labels: labels, onTerms: onTerms, onPrivacy: onPrivacy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsLine extends StatelessWidget {
  final WelcomeLabels labels;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const _TermsLine({required this.labels, required this.onTerms, required this.onPrivacy});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'Ubuntu',
      fontSize: 12,
      height: 1.6,
      color: BrandColors.inkFaint,
    );
    final link = base.copyWith(color: BrandColors.primary, fontWeight: FontWeight.w500);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: labels.agreePrefix),
          TextSpan(
            // Non-breaking spaces keep the link phrase whole — the line wraps
            // between phrases, never mid-"Terms of Service".
            text: labels.termsLink.replaceAll(' ', ' '),
            style: link,
            recognizer: TapGestureRecognizer()..onTap = onTerms,
          ),
          TextSpan(text: labels.agreeMiddle),
          TextSpan(
            text: labels.privacyLink.replaceAll(' ', ' '),
            style: link,
            recognizer: TapGestureRecognizer()..onTap = onPrivacy,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
