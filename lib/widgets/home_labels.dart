import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// The home cards' strings.
HomeLabels homeLabels(AppLocalizations i18n) => HomeLabels(
  incomingTitle: i18n.shared.homeIncomingTitle,
  incomingMore: i18n.shared.homeIncomingTitleMore,
  unlocksIn: i18n.shared.homeIncomingUnlocksIn,
  confirmations: i18n.shared.homeIncomingConfirmations,
  change: i18n.shared.homeIncomingChange,
  chartTitle: i18n.shared.homeChartTitle,
  chartToday: i18n.shared.homeChartToday,
  chartEachCoin: i18n.shared.homeChartEachCoin,
  chartNew: i18n.shared.homeChartNew,
  chartEmpty: i18n.shared.homeChartEmpty,
);

/// The security checklist's strings.
SecurityChecklistLabels securityChecklistLabels(AppLocalizations i18n) => SecurityChecklistLabels(
  title: i18n.shared.homeChecklistTitle,
  progress: i18n.shared.homeChecklistProgress,
  verifySeed: i18n.shared.homeChecklistVerifySeed,
  autoBackup: i18n.shared.homeChecklistAutoBackup,
  tor: i18n.shared.homeChecklistTor,
  privateLookups: i18n.shared.homeChecklistPrivateLookups,
  securityKeys: i18n.shared.homeChecklistSecurityKeys,
);

/// The Security Checklist settings card's strings.
SecurityChecklistSheetLabels securityChecklistSheetLabels(AppLocalizations i18n) =>
    SecurityChecklistSheetLabels(
      title: i18n.shared.securityChecklistLabel,
      subtitle: i18n.shared.securityChecklistSheetSubtitle,
      homeSection: i18n.shared.securityChecklistHomeSection,
      showOnHome: i18n.shared.securityChecklistShowOnHome,
      showOnHomeDesc: i18n.shared.securityChecklistShowOnHomeDesc,
      stepsSection: i18n.shared.securityChecklistStepsSection,
      done: i18n.shared.securityChecklistStepDone,
      notDone: i18n.shared.securityChecklistStepNotDone,
      seedDone: i18n.shared.securityChecklistSeedDone,
      steps: securityChecklistLabels(i18n),
      save: i18n.shared.save,
      cancel: i18n.shared.cancel,
    );
