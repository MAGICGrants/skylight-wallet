import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/fiat_rate_model.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/socks_http.dart';

/// Shared form widget used by both TorSettingsScreen and the Tor settings dialog
class TorSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final VoidCallback onSaved;

  const TorSettingsForm({super.key, required this.saveButtonLabel, required this.onSaved});

  @override
  State<TorSettingsForm> createState() => _TorSettingsFormState();
}

class _TorSettingsFormState extends State<TorSettingsForm> {
  TorMode _selectedMode = TorMode.builtIn;
  final TextEditingController _socksPortController = TextEditingController();
  bool _useOrbot = false;

  bool _isTestingConnection = false;
  bool _hasTested = false;
  bool _connectionSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final torSettings = TorSettingsService.sharedInstance;
    setState(() {
      _selectedMode = torSettings.torMode;
      _useOrbot = torSettings.useOrbot;
      _socksPortController.text = _useOrbot ? '9050' : torSettings.socksPort;
    });
  }

  Future<void> _saveSettings() async {
    final torSettings = TorSettingsService.sharedInstance;
    await torSettings.save(
      torMode: _selectedMode,
      socksPort: _socksPortController.text,
      useOrbot: _useOrbot,
    );
  }

  void _onSavePressed() async {
    // Read before the await: a Tor-only connection has to be told immediately
    // that its requirement can no longer be met, or it goes on presenting
    // itself as connected over Tor until something tries to reconnect.
    final wallet = appWalletOf(context);
    final previousMode = TorSettingsService.sharedInstance.torMode;
    final disablingTor = _selectedMode == TorMode.disabled && previousMode != TorMode.disabled;
    final enablingTor = _selectedMode != TorMode.disabled && previousMode == TorMode.disabled;

    // Warn before cutting Tor out from under a wallet connected over it. Cancel
    // leaves everything as-is; confirm marks the connection broken so nothing
    // reconnects until the user reconfigures it.
    if (disablingTor && wallet.usingTor) {
      final confirmed = await _confirmDisableTor();
      if (confirmed != true) return;
      wallet.onGlobalTorDisabled();
    }

    var fiatChanged = false;

    // The fiat API can't reach Kraken over a Tor that's now off, so a Tor-only
    // fiat setting is turned off too (the setup form won't offer Tor again while
    // global Tor is disabled). Remember it was us, not the user, so re-enabling
    // Tor can restore it.
    if (disablingTor && await FiatRateModel.loadFiatApiMode() == FiatApiMode.torOnly) {
      await FiatRateModel.saveFiatApiMode(FiatApiMode.disabled);
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.fiatAutoDisabledByTor, true);
      fiatChanged = true;
    }

    // Turning Tor back on restores the fiat API to Tor mode, but only if we were
    // the ones who disabled it (a user who disabled it themselves keeps it off).
    if (enablingTor &&
        (await SharedPreferencesService.get<bool>(SharedPreferencesKeys.fiatAutoDisabledByTor) ??
            false)) {
      await FiatRateModel.saveFiatApiMode(FiatApiMode.torOnly);
      await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
      fiatChanged = true;
    }

    await _saveSettings();
    if (!mounted) return;
    if (fiatChanged) Provider.of<FiatRateModel>(context, listen: false).startService();
    widget.onSaved();
  }

  Future<bool?> _confirmDisableTor() async {
    final i18n = AppLocalizations.of(context)!;
    final dialogWidth = MediaQuery.of(context).size.width.clamp(0.0, 500.0);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        constraints: BoxConstraints.tightFor(width: dialogWidth),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Text(i18n.torDisabledWalletsWarningTitle),
        content: Text(i18n.torDisabledWalletsWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(i18n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(i18n.torDisabledWalletsWarningConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (_isTestingConnection) {
      return;
    }

    if (_selectedMode != TorMode.external) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _hasTested = true;
      _connectionSuccess = false;
    });

    try {
      final port = int.tryParse(_socksPortController.text) ?? 9050;
      final proxyInfo = (host: InternetAddress.loopbackIPv4, port: port);

      final response = await makeSocksHttpRequest(
        'GET',
        'https://check.torproject.org/api/ip',
        proxyInfo,
      ).timeout(Duration(seconds: 15));

      // Check if the response indicates we're connected through Tor
      final isTor = response.jsonBody != null && response.jsonBody['IsTor'] == true;

      setState(() {
        _connectionSuccess = response.statusCode == HttpStatus.ok && isTor;
      });
    } catch (e) {
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _socksPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        DropdownButtonFormField<TorMode>(
          initialValue: _selectedMode,
          decoration: InputDecoration(
            labelText: i18n.torSettingsModeLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          items: [
            DropdownMenuItem(value: TorMode.builtIn, child: Text(i18n.torSettingsModeBuiltIn)),
            DropdownMenuItem(value: TorMode.external, child: Text(i18n.torSettingsModeExternal)),
            DropdownMenuItem(value: TorMode.disabled, child: Text(i18n.torSettingsModeDisabled)),
          ],
          onChanged: (TorMode? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedMode = newValue;
                _hasTested = false;
              });
            }
          },
        ),
        if (_selectedMode == TorMode.external)
          TextFormField(
            controller: _socksPortController,
            enabled: !_useOrbot || !(Platform.isAndroid || Platform.isIOS),
            decoration: InputDecoration(
              labelText: i18n.torSettingsSocksPortLabel,
              hintText: i18n.torSettingsSocksPortHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              suffixIcon: _hasTested && !_isTestingConnection
                  ? Icon(_connectionSuccess ? Icons.check : Icons.cancel_outlined)
                  : null,
              suffixIconColor: _connectionSuccess ? Colors.teal : Colors.red,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {
              setState(() {
                _hasTested = false;
              });
            },
          ),
        if (_selectedMode == TorMode.external && (Platform.isAndroid || Platform.isIOS))
          CheckboxListTile(
            title: Text(
              Platform.isIOS ? i18n.torSettingsUseOrbotLabelIos : i18n.torSettingsUseOrbotLabel,
            ),
            value: _useOrbot,
            onChanged: (value) {
              setState(() {
                _useOrbot = value ?? false;
                if (_useOrbot) {
                  _socksPortController.text = '9050';
                }
                _hasTested = false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            if (_selectedMode == TorMode.external)
              TextButton.icon(
                label: Text(i18n.torSettingsTestConnectionButton),
                onPressed: _testConnection,
                icon: _isTestingConnection
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.network_check),
              ),
            if (_selectedMode != TorMode.external ||
                (_connectionSuccess && _hasTested && !_isTestingConnection))
              FilledButton(onPressed: _onSavePressed, child: Text(widget.saveButtonLabel)),
          ],
        ),
      ],
    );
  }
}
