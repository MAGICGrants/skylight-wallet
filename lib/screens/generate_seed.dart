import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart' show SeedSource;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/secure_screen.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> with SecureScreenMixin {
  List<String>? _seed;
  ({SeedSource seed, DateTime restoreDate})? _generated;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    // Generate the seed in memory only — nothing is written to disk until the
    // user confirms their backup and taps Continue (_commit).
    final generated = generateWalletSeed(context);
    _generated = generated;
    _seed = generated.seed.mnemonic.split(' ');
  }

  Future<void> _continue() async {
    if (_committing || _generated == null) return;
    setState(() => _committing = true);

    try {
      // This is where the wallet file is actually written to disk.
      final restoreHeight = await commitGeneratedWallet(
        context,
        seed: _generated!.seed,
        restoreDate: _generated!.restoreDate,
      );
      if (!mounted) return;
      Provider.of<FiatRateModel>(context, listen: false).startService();
      // Wallet Details is LWS whitelisting info; a full node needs none of it.
      if (appWalletOf(context).isNodeMode) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/lws_details',
          (Route<dynamic> route) => false,
          arguments: restoreHeight,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _committing = false);
      var errorMsg = 'Sorry, something went wrong.';
      if (error.toString().contains('failedToLoadHeight')) {
        errorMsg = 'Check your internet connection.';
      } else {
        log(LogLevel.error, error.toString());
      }
      showBrandToast(context, errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return GenerateSeedView(
      stepCount: 5,
      stepIndex: 4,
      seedWords: _seed,
      birthdayCard: null,
      continueLoading: _committing,
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
