import 'package:flutter/widgets.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/home_labels.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_backup_platform/wallet_backup_platform.dart' show MetadataBackupSetup;
import 'package:wallet_domain/wallet_domain.dart' show SeedStore;
import 'package:wallet_fhse/security_keys_ui.dart' show securityKeysOn;

/// The security checklist as Skylight reads it: the home's card, and the
/// Security Checklist card in Settings, which shows where each step stands.
SecurityChecklist appSecurityChecklist(BuildContext context) {
  bool? seedAskable;
  return SecurityChecklist(
    autoBackupOn: MetadataBackupSetup.automaticBackupOn,
    securityKeysOn: securityKeysOn,
    // The seed check asks for the words as kept since the wallet was made, or,
    // for an older wallet, its polyseed. Worked out once per checklist.
    canVerifySeed: () async {
      final known = seedAskable;
      if (known != null) return known;
      var askable = await SeedStore.exists();
      if (!askable && context.mounted) {
        askable = (await appWalletOf(context).readPolyseed()).isNotEmpty;
      }
      return seedAskable = askable;
    },
  );
}

/// Opens Settings' Security Checklist card. True when the user saved.
Future<bool?> showAppSecurityChecklistSheet(BuildContext context) async {
  final checklist = appSecurityChecklist(context);
  try {
    return await showSecurityChecklistSheet(
      context,
      checklist: checklist,
      labels: securityChecklistSheetLabels(AppLocalizations.of(context)!),
    );
  } finally {
    checklist.dispose();
  }
}
