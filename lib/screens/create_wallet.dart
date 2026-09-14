import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
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

    return CreateWalletView(
      stepCount: 5,
      stepIndex: 3,
      labels: CreateWalletLabels(
        title: i18n.createWalletTitle,
        subtitle: i18n.createWalletDescription,
        createNew: i18n.createWalletCreateNewButton,
        createNewDesc: i18n.createWalletCreateNewDesc,
        restore: i18n.createWalletRestoreExistingButton,
        restoreDesc: i18n.createWalletRestoreExistingDesc,
      ),
      onCreateNew: () => Navigator.pushNamed(context, '/generate_seed'),
      onRestore: _restoreExisting,
    );
  }
}
