import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/screens/desktop/wallet_setup_view.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class CreateWalletScreenArgs {
  String toastMessage;

  CreateWalletScreenArgs({required this.toastMessage});
}

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  @override
  void initState() {
    super.initState();
    _showErrorIfNeeded();
  }

  void _showErrorIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as CreateWalletScreenArgs?;

      if (args != null && args.toastMessage != '') {
        showBrandToast(context, args.toastMessage);
      }
    });
  }

  void _restoreExisting() {
    Navigator.pushNamed(context, '/restore_wallet');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final labels = CreateWalletLabels(
      title: i18n.shared.createWalletTitle,
      subtitle: i18n.createWalletDescription,
      createNew: i18n.shared.createNewWalletChoice,
      createNewDesc: i18n.createWalletCreateNewDesc,
      restore: i18n.shared.restoreExistingWalletChoice,
      restoreDesc: i18n.createWalletRestoreExistingDesc,
    );
    void createNew() => Navigator.pushNamed(context, '/generate_seed');

    if (isDesktop) {
      return DesktopWalletSetupView(
        labels: labels,
        continueText: i18n.shared.continueText,
        noteGenerated: i18n.shared.onboardingWalletNoteGenerated(appShortName),
        noteRestore: i18n.shared.onboardingWalletNoteRestore,
        onCreateNew: createNew,
        onRestore: _restoreExisting,
        onBack: () => Navigator.pop(context),
      );
    }

    return CreateWalletView(
      stepCount: 6,
      stepIndex: 3,
      labels: labels,
      onCreateNew: createNew,
      onRestore: _restoreExisting,
    );
  }
}
