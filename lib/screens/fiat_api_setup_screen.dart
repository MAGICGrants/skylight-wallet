import 'dart:io';

import 'package:flutter/material.dart';

import 'package:skylight_wallet/consts.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';

class FiatApiSetupScreen extends StatefulWidget {
  const FiatApiSetupScreen({super.key});

  @override
  State<FiatApiSetupScreen> createState() => _FiatApiSetupScreenState();
}

class _FiatApiSetupScreenState extends State<FiatApiSetupScreen> {
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
  String _fiatCurrency = 'USD';

  bool get _globalTorDisabled =>
      TorSettingsService.sharedInstance.torMode == TorMode.disabled;

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
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatRate);

    if (!mounted) return;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      Navigator.pushNamed(context, '/create_wallet_password');
    } else {
      Navigator.pushNamed(context, '/create_wallet');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Monero Wallet')),
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
                    Text(
                      i18n.fiatApiSetupTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
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
                      value: _fiatMode,
                      items: [
                        if (!_globalTorDisabled)
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
                        value: _fiatCurrency,
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
                    FilledButton(
                      onPressed: _onContinue,
                      child: Text(i18n.lwsSetupContinueButton),
                    ),
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
