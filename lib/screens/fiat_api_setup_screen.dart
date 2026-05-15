import 'package:flutter/material.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';

class FiatApiSetupScreen extends StatefulWidget {
  const FiatApiSetupScreen({super.key});

  @override
  State<FiatApiSetupScreen> createState() => _FiatApiSetupScreenState();
}

class _FiatApiSetupScreenState extends State<FiatApiSetupScreen> {
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
  String _fiatCurrency = 'USD';

  Future<void> _onContinue() async {
    await FiatRateModel.saveFiatApiMode(_fiatMode);
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, _fiatCurrency);
    await FiatRateModel.clearPersistedRates();

    if (!mounted) return;
    Navigator.pushNamed(context, '/create_wallet_password');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Wallet')),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                Column(
                  spacing: 10,
                  children: [
                    Text(i18n.fiatApiSetupTitle, style: theme.textTheme.headlineMedium),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        i18n.fiatApiSetupDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                Column(
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<FiatApiMode>(
                      decoration: InputDecoration(
                        labelText: i18n.fiatApiSettingsModeLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      initialValue: _fiatMode,
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
                        if (v != null) setState(() => _fiatMode = v);
                      },
                    ),
                    if (_fiatMode != FiatApiMode.disabled)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: i18n.fiatApiSettingsDisplayCurrencyLabel,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        initialValue: _fiatCurrency,
                        items: supportedFiatCurrencies
                            .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _fiatCurrency = v);
                        },
                      ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(onPressed: _onContinue, child: Text(i18n.lwsSetupContinueButton)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
