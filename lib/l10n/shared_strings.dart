import 'package:flutter/widgets.dart' show Locale;
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:wallet_ui/wallet_ui.dart' show WalletUiLocalizations, lookupWalletUiLocalizations;

/// The app's name where a shared string says it (`{appName}`).
const appShortName = 'Skylight';

/// The strings both apps word the same live in wallet-core
/// ([WalletUiLocalizations]); `i18n.shared` reads them in the app's own
/// locale, so a screen that holds [AppLocalizations] needs nothing else.
/// What goes there and what stays here: wallet-core's docs/strings.md.
extension SharedStrings on AppLocalizations {
  WalletUiLocalizations get shared =>
      lookupWalletUiLocalizations(Locale(localeName.split(RegExp('[_-]')).first));
}
