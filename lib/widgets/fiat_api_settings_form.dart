import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/l10n/shared_strings.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

class FiatApiSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final Future<void> Function() onSaved;

  /// In a settings sheet: a Cancel beside Save, as on the other settings sheets.
  final VoidCallback? onCancel;

  const FiatApiSettingsForm({
    super.key,
    required this.saveButtonLabel,
    required this.onSaved,
    this.onCancel,
  });

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
    await FiatRateModel.clearPersistedRates();
    await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    final save = BrandButton(label: widget.saveButtonLabel, onPressed: _save);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FiatModesView(
          modeLabel: i18n.shared.fiatApiSettingsModeLabel,
          torOnly: i18n.shared.fiatApiSettingsModeTorOnly,
          torOnlyDesc: i18n.shared.fiatModeTorOnlyDesc,
          clearnet: i18n.shared.clearnetOnlyChoice,
          clearnetDesc: i18n.shared.fiatModeClearnetDesc,
          disabled: i18n.shared.fiatApiSettingsModeDisabled,
          disabledDesc: i18n.shared.fiatModeDisabledDesc,
          offerTorOnly: !_globalTorDisabled,
          modeIndex: _mode.index,
          onModeChanged: (i) => setState(() => _mode = FiatApiMode.values[i]),
          currencyLabel: i18n.shared.fiatApiSettingsDisplayCurrencyLabel,
          currency: _currency,
          onCurrencyChanged: (c) => setState(() => _currency = c),
        ),
        const SizedBox(height: 18),
        if (widget.onCancel == null)
          save
        else
          SheetActions(
            primary: save,
            secondary: BrandButton.ghost(
              label: i18n.shared.cancel,
              color: BrandColors.inkMuted,
              onPressed: widget.onCancel,
            ),
          ),
      ],
    );
  }
}
