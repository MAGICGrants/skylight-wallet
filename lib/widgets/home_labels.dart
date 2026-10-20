import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// The home cards' strings.
HomeLabels homeLabels(AppLocalizations i18n) => HomeLabels(
  incomingTitle: i18n.homeIncomingTitle,
  incomingMore: i18n.homeIncomingTitleMore,
  unlocksIn: i18n.homeIncomingUnlocksIn,
  confirmations: i18n.homeIncomingConfirmations,
  chartTitle: i18n.homeChartTitle,
  chartToday: i18n.homeChartToday,
  chartEachCoin: i18n.homeChartEachCoin,
  chartNew: i18n.homeChartNew,
  chartEmpty: i18n.homeChartEmpty,
);

/// The security checklist's strings.
SecurityChecklistLabels securityChecklistLabels(AppLocalizations i18n) => SecurityChecklistLabels(
  title: i18n.homeChecklistTitle,
  progress: i18n.homeChecklistProgress,
  verifySeed: i18n.homeChecklistVerifySeed,
  autoBackup: i18n.homeChecklistAutoBackup,
  tor: i18n.homeChecklistTor,
  privateLookups: i18n.homeChecklistPrivateLookups,
  securityKeys: i18n.homeChecklistSecurityKeys,
);
