import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart' show OpenAliasMode;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/widgets/fiat_api_settings_form.dart';
import 'package:skylight_wallet/widgets/tor_settings_form.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

// The privacy settings sheets, shared by Settings and the home's security
// checklist so both open the same thing.

double _sheetMaxHeight(BuildContext sheetContext) {
  final media = MediaQuery.of(sheetContext);
  return (media.size.height - media.viewInsets.bottom) * 0.86;
}

/// Settings popup chrome, matching Spice's sheets: a handle, an icon + title
/// header, then the form scrolling below (the form carries its own save
/// button and pops on success).
Future<void> showSettingsFormSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget form,
}) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      // Desktop modal: the card owns the edge padding and drops the drag handle.
      final hpad = isDesktopModal ? 0.0 : 22.0;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: _sheetMaxHeight(sheetContext)),
          child: Padding(
            padding: EdgeInsets.only(top: isDesktopModal ? 0 : 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Padding(
                  padding: EdgeInsets.fromLTRB(hpad, 0, hpad, 16),
                  child: Row(
                    children: [
                      SheetIcon(
                        icon: icon,
                        bg: BrandColors.surfaceTinted,
                        color: BrandColors.primaryDeep,
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Text(title, style: BrandText.sheetTitle)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hpad, 0, hpad, isDesktopModal ? 0 : 16),
                    child: form,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Tor: built in, external or off. Saving reconnects the wallet and restarts
/// the price feed, which follows the Tor choice.
Future<void> showTorSettingsSheet(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  return showSettingsFormSheet(
    context,
    icon: Icons.public,
    title: i18n.torSettingsTitle,
    form: Builder(
      builder: (formContext) => TorSettingsForm(
        saveButtonLabel: i18n.torSettingsSaveButton,
        onSaved: () {
          appWalletOf(formContext).load();
          Provider.of<FiatRateModel>(formContext, listen: false).startService();
          Navigator.pop(formContext);
        },
      ),
    ),
  );
}

/// The price source: Tor-only, clearnet or off.
Future<void> showFiatApiSettingsSheet(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  return showSettingsFormSheet(
    context,
    icon: Icons.attach_money,
    title: i18n.settingsFiatApiSettingsLabel,
    form: Builder(
      builder: (formContext) => FiatApiSettingsForm(
        saveButtonLabel: i18n.torSettingsSaveButton,
        onSaved: () async {
          await Provider.of<FiatRateModel>(formContext, listen: false).startService();
          if (formContext.mounted) Navigator.pop(formContext);
        },
      ),
    ),
  );
}

/// OpenAlias lookups: Tor-only, clearnet or off. True when the user saved.
Future<bool?> showOpenAliasSheet(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  return showOpenAliasSettingsSheet(
    context,
    labels: OpenAliasSettingsLabels(
      title: i18n.settingsOpenAliasSettingsLabel,
      subtitle: i18n.openAliasSettingsSheetSubtitle,
      modeLabel: i18n.fiatApiSettingsModeLabel,
      torOnly: i18n.fiatApiSettingsModeTorOnly,
      torOnlyDesc: i18n.openAliasModeTorOnlyDesc,
      clearnet: i18n.fiatApiSettingsModeClearnet,
      clearnetDesc: i18n.openAliasModeClearnetDesc,
      disabled: i18n.fiatApiSettingsModeDisabled,
      disabledDesc: i18n.openAliasModeDisabledDesc,
      save: i18n.torSettingsSaveButton,
      cancel: i18n.cancel,
    ),
  );
}

/// Opens whichever of the price source and OpenAlias still goes over
/// clearnet, one after the other: the checklist step that covers both.
Future<void> showPrivateLookupSheets(BuildContext context) async {
  if (await FiatRateModel.loadFiatApiMode() == FiatApiMode.clearnet) {
    if (!context.mounted) return;
    await showFiatApiSettingsSheet(context);
  }
  if (await OpenAliasMode.load() == OpenAliasMode.clearnet) {
    if (!context.mounted) return;
    await showOpenAliasSheet(context);
  }
}
