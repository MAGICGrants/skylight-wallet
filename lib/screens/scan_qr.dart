import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Optional arguments for the scan route. When [accept] is given, the scanner
/// only returns a code it accepts and keeps scanning otherwise, so an unexpected
/// QR never pops back; [invalidMessage] is shown (throttled) on a reject.
class ScanQrArgs {
  final bool Function(String text) accept;
  final String? invalidMessage;

  const ScanQrArgs({required this.accept, this.invalidMessage});
}

class ScanQrScreen extends StatelessWidget {
  const ScanQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ScanQrArgs?;

    return ScanQrView(
      title: i18n.scanQrTitle,
      accept: args?.accept,
      invalidMessage: args?.invalidMessage,
      onResult: (text) => Navigator.pop(context, text),
      onBack: () => Navigator.pop(context),
    );
  }
}
