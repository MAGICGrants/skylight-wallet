import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylight_wallet/l10n/app_localizations.dart';
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
    await _saveSettings();
    widget.onSaved();
  }

  Future<void> _testConnection() async {
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
            title: Text(i18n.torSettingsUseOrbotLabel),
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
                onPressed: _isTestingConnection ? null : _testConnection,
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
