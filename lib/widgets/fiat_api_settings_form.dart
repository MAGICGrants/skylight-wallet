import 'package:flutter/material.dart';

import 'package:spice_wallet/consts.dart';
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';

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
    final mode = await FiatRateModel.loadFiatApiMode();
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

  Future<void> _save() async {
    await FiatRateModel.saveFiatApiMode(_mode);
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, _currency);
    await FiatRateModel.clearPersistedRates();
    await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return SizedBox(width: 280, height: 120, child: Center(child: CircularProgressIndicator()));
    }
    final i18n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        DropdownButtonFormField<FiatApiMode>(
          decoration: InputDecoration(
            labelText: i18n.fiatApiSettingsModeLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          initialValue: _mode,
          items: [
            DropdownMenuItem(
              value: FiatApiMode.torOnly,
              child: Text(i18n.fiatApiSettingsModeTorOnly),
            ),
            DropdownMenuItem(
              value: FiatApiMode.clearnet,
              child: Text(i18n.fiatApiSettingsModeClearnet),
            ),
            DropdownMenuItem(
              value: FiatApiMode.disabled,
              child: Text(i18n.fiatApiSettingsModeDisabled),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _mode = v);
          },
        ),
        if (_mode != FiatApiMode.disabled)
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: i18n.fiatApiSettingsDisplayCurrencyLabel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            initialValue: _currency,
            items: supportedFiatCurrencies
                .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _currency = v);
            },
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _save, child: Text(widget.saveButtonLabel)),
        ),
      ],
    );
  }
}
