import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// The home cards' strings.
HomeLabels homeLabels(AppLocalizations i18n) => HomeLabels(
  incomingTitle: i18n.shared.homeIncomingTitle,
  incomingMore: i18n.shared.homeIncomingTitleMore,
  unlocksIn: i18n.shared.homeIncomingUnlocksIn,
  confirmations: i18n.shared.homeIncomingConfirmations,
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
