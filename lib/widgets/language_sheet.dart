import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/language_model.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Native + English display names for the supported locales.
const languageNames = {'en': ('English', 'English'), 'pt': ('Português', 'Portuguese (Brazil)')};

/// Opens the language picker — reachable from Settings and the welcome screen
/// (welcome has no route to Settings, so a reader who can't read it can switch
/// here before anything else).
void showLanguageSheet(BuildContext context) {
  final language = context.read<LanguageModel>();
  showLanguagePickerSheet(
    context,
    // Resolved per build from the sheet's own context rather than captured
    // here: picking a language re-localizes the app while this sheet is still
    // the thing on screen, and a snapshot would leave it in the old language --
    // looking for all the world like the setting did not take.
    labels: (context) {
      final i18n = AppLocalizations.of(context)!;
      return SettingsPickerLabels(
        title: i18n.settingsLanguageLabel,
        subtitle: i18n.settingsLanguageSheetSubtitle,
        done: i18n.done,
      );
    },
    options: [
      for (final locale in AppLocalizations.supportedLocales)
        LanguagePickerOption(
          code: locale.languageCode,
          native: languageNames[locale.languageCode]?.$1 ?? locale.languageCode,
          english: languageNames[locale.languageCode]?.$2 ?? '',
        ),
    ],
    selected: language.language,
    onSelect: language.setLanguage,
    iconBg: BrandColors.surfaceTinted,
    iconColor: BrandColors.primaryDeep,
  );
}
