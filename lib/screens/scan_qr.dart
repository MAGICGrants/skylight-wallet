import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class ScanQrScreen extends StatelessWidget {
  const ScanQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return ScanQrView(
      title: i18n.scanQrTitle,
      onResult: (text) => Navigator.pop(context, text),
      onBack: () => Navigator.pop(context),
    );
  }
}
