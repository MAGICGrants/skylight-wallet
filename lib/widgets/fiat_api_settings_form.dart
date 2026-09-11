import 'package:flutter/material.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class FiatApiSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final Future<void> Function() onSaved;

  const FiatApiSettingsForm({super.key, required this.saveButtonLabel, required this.onSaved});

  @override
  State<FiatApiSettingsForm> createState() => _FiatApiSettingsFormState();
}

class _FiatApiSettingsFormState extends State<FiatApiSettingsForm> {
  FiatApiMode _mode = FiatApiMode.torOnly;
  String _currency = 'USD';
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var mode = await FiatRateModel.loadFiatApiMode();
    // Tor-only fiat is unreachable with global Tor off; fall back to clearnet.
    if (mode == FiatApiMode.torOnly && _globalTorDisabled) {
      mode = FiatApiMode.clearnet;
    }
    final cur =
        await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatCurrency) ?? 'USD';
    if (mounted) {
      setState(() {
        _mode = mode;
        _currency = cur;
        _loaded = true;
      });
    }
  }

  bool get _globalTorDisabled => TorSettingsService.sharedInstance.torMode == TorMode.disabled;

  Future<void> _save() async {
    await FiatRateModel.saveFiatApiMode(_mode);
    // A manual choice takes over from the Tor auto-disable, so re-enabling Tor
    // no longer overrides it.
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, _currency);
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatRate);
    await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FiatModesView(
          modeLabel: i18n.fiatApiSettingsModeLabel,
          torOnly: i18n.fiatApiSettingsModeTorOnly,
          torOnlyDesc: i18n.fiatModeTorOnlyDesc,
          clearnet: i18n.fiatApiSettingsModeClearnet,
          clearnetDesc: i18n.fiatModeClearnetDesc,
          disabled: i18n.fiatApiSettingsModeDisabled,
          disabledDesc: i18n.fiatModeDisabledDesc,
          offerTorOnly: !_globalTorDisabled,
          modeIndex: _mode.index,
          onModeChanged: (i) => setState(() => _mode = FiatApiMode.values[i]),
          currencyLabel: i18n.fiatApiSettingsDisplayCurrencyLabel,
          currencies: [
            for (final code in supportedFiatCurrencies)
              FiatCurrencyOption(code: code, symbol: currencySymbols[code] ?? ''),
          ],
          currency: _currency,
          onCurrencyChanged: (c) => setState(() => _currency = c),
        ),
        const SizedBox(height: 18),
        BrandButton(label: widget.saveButtonLabel, onPressed: _save),
      ],
    );
  }
}
