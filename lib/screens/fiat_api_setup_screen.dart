import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/screens/desktop/fiat_setup_view.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/platform.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class FiatApiSetupScreen extends StatefulWidget {
  const FiatApiSetupScreen({super.key});

  @override
  State<FiatApiSetupScreen> createState() => _FiatApiSetupScreenState();
}

class _FiatApiSetupScreenState extends State<FiatApiSetupScreen> {
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
  String _fiatCurrency = 'USD';

  bool get _globalTorDisabled => TorSettingsService.sharedInstance.torMode == TorMode.disabled;

  @override
  void initState() {
    super.initState();
    // Tor-only fiat is unreachable with global Tor off; default to clearnet.
    if (_globalTorDisabled) _fiatMode = FiatApiMode.clearnet;
  }

  Future<void> _onContinue() async {
    await FiatRateModel.saveFiatApiMode(_fiatMode);
    // A manual choice is definitive; don't let a later Tor re-enable override it.
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, _fiatCurrency);
    await FiatRateModel.clearPersistedRates();

    if (!mounted) return;
    Navigator.pushNamed(context, '/connection_setup');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final labels = FiatSetupLabels(
      title: i18n.shared.fiatApiSetupTitle,
      subtitle: i18n.fiatApiSetupDescription,
      torOnly: i18n.shared.fiatApiSettingsModeTorOnly,
      torOnlyDesc: i18n.shared.fiatModeTorOnlyDesc,
      clearnet: i18n.shared.clearnetOnlyChoice,
      clearnetDesc: i18n.shared.fiatModeClearnetDesc,
      disabled: i18n.shared.fiatApiSettingsModeDisabled,
      disabledDesc: i18n.shared.fiatModeDisabledDesc,
      currencyLabel: i18n.shared.fiatApiSettingsDisplayCurrencyLabel,
      continueText: i18n.shared.continueText,
    );

    if (isDesktop) {
      return DesktopFiatSetupView(
        labels: labels,
        noteRatesOnly: i18n.shared.onboardingPriceNoteRatesOnly,
        noteTor: i18n.shared.onboardingPriceNoteTor,
        modeIndex: _fiatMode.index,
        currency: _fiatCurrency,
        offerTorOnly: !_globalTorDisabled,
        onModeChanged: (i) => setState(() => _fiatMode = FiatApiMode.values[i]),
        onCurrencyChanged: (code) => setState(() => _fiatCurrency = code),
        onContinue: _onContinue,
        onBack: () => Navigator.pop(context),
      );
    }

    return FiatSetupView(
      labels: labels,
      modeIndex: _fiatMode.index,
      currency: _fiatCurrency,
      offerTorOnly: !_globalTorDisabled,
      onModeChanged: (i) => setState(() => _fiatMode = FiatApiMode.values[i]),
      onCurrencyChanged: (code) => setState(() => _fiatCurrency = code),
      onContinue: _onContinue,
      stepCount: 6,
      stepIndex: 1,
    );
  }
}
