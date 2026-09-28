import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/desktop/create_password_view.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Carries the wallet commit (create or restore) to the final password step,
/// which sets the password then writes the wallet (the password-last flow).
class CreateWalletPasswordArgs {
  /// Commits the wallet using [ctx] (the password is already set); returns the
  /// wallet's restore height, for the LWS-details step.
  final Future<int> Function(BuildContext ctx) commit;
  const CreateWalletPasswordArgs({required this.commit});
}

class CreateWalletPasswordScreen extends StatefulWidget {
  const CreateWalletPasswordScreen({super.key});

  @override
  State<CreateWalletPasswordScreen> createState() => _CreateWalletPasswordScreenState();
}

class _CreateWalletPasswordScreenState extends State<CreateWalletPasswordScreen> {
  bool _isLoading = false;

  /// Sets the password, then commits the wallet from the seed/restore carried in
  /// [args]. Node mode goes straight home; LWS mode shows its whitelisting info.
  Future<void> _createWallet(String password, CreateWalletPasswordArgs args) async {
    setState(() => _isLoading = true);
    try {
      setWalletPassword(context, password);
      final restoreHeight = await args.commit(context);
      if (!mounted) return;
      Provider.of<FiatRateModel>(context, listen: false).startService();
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
      setState(() => _isLoading = false);
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
    final args = ModalRoute.of(context)?.settings.arguments as CreateWalletPasswordArgs?;

    final labels = CreatePasswordLabels(
      title: i18n.createWalletPasswordTitle,
      description: i18n.createWalletPasswordDescription,
      passwordHint: i18n.createWalletPasswordHint,
      confirmPasswordHint: i18n.createWalletConfirmPasswordHint,
      submit: i18n.continueText,
      fieldEmptyError: i18n.fieldEmptyError,
      tooShortError: i18n.passwordTooShortError,
      doNotMatchError: i18n.passwordsDoNotMatchError,
    );

    void submit(String password) {
      if (args != null) _createWallet(password, args);
    }

    if (isDesktop) {
      return DesktopCreatePasswordView(
        labels: labels,
        continueText: i18n.continueText,
        noteLaunch: i18n.onboardingPasswordNoteLaunch,
        noteNotCloud: i18n.onboardingPasswordNoteNotCloud,
        strongLabel: i18n.onboardingPasswordStrong,
        matchLabel: i18n.onboardingPasswordMatch,
        loading: _isLoading,
        onSubmit: submit,
        onBack: () => Navigator.pop(context),
      );
    }

    return CreatePasswordView(loading: _isLoading, onSubmit: submit, labels: labels);
  }
}
