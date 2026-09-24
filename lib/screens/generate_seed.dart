import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:wallet_domain/wallet_domain.dart' show SeedSource;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/create_wallet_password.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> with SecureScreenMixin {
  List<String>? _seed;
  ({SeedSource seed, DateTime restoreDate})? _generated;

  @override
  void initState() {
    super.initState();
    // Generate the seed in memory only — nothing is written to disk until the
    // password step commits the wallet (password-last flow).
    final generated = generateWalletSeed(context);
    _generated = generated;
    _seed = generated.seed.mnemonic.split(' ');
  }

  /// Carry the generated seed to the password step, which sets the password and
  /// writes the wallet.
  void _continue() {
    final generated = _generated;
    if (generated == null) return;
    Navigator.pushNamed(
      context,
      '/create_wallet_password',
      arguments: CreateWalletPasswordArgs(
        commit: (ctx) =>
            commitGeneratedWallet(ctx, seed: generated.seed, restoreDate: generated.restoreDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    if (isDesktop) {
      return DesktopGenerateSeedView(
        logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
        step: 5,
        totalSteps: 6,
        title: i18n.generateSeedTitle,
        description: i18n.generateSeedSubtitleRevealed,
        seedWords: _seed ?? const [],
        birthdayLabel: i18n.generateSeedBirthdayLabel,
        birthdayReason: i18n.generateSeedBirthdayReason,
        birthdayValue: _generated != null
            ? DateFormat.yMMM(
                Localizations.localeOf(context).toString(),
              ).format(_generated!.restoreDate)
            : null,
        confirmLabel: i18n.generateSeedConfirm,
        passwordNote: i18n.onboardingSeedNotePassword,
        revealLabel: i18n.generateSeedReveal,
        continueText: i18n.continueText,
        onContinue: _continue,
        onBack: () => Navigator.pop(context),
      );
    }

    return GenerateSeedView(
      stepCount: 6,
      stepIndex: 4,
      seedWords: _seed,
      birthdayCard: null,
      onContinue: _continue,
      labels: GenerateSeedLabels(
        titleCovered: i18n.generateSeedTitleCovered,
        titleRevealed: i18n.generateSeedTitle,
        subtitleCovered: i18n.generateSeedSubtitleCovered,
        subtitleRevealed: i18n.generateSeedSubtitleRevealed,
        reveal: i18n.generateSeedReveal,
        screenshotNote: i18n.generateSeedScreenshotNote,
        confirm: i18n.generateSeedConfirm,
        continueText: i18n.continueText,
      ),
    );
  }
}
