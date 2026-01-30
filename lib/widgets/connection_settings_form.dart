import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylight_wallet/services/tor_settings_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/socks_http.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/services/tor_service.dart';

const isDemoMode = String.fromEnvironment('DEMO_MODE') == 'true';

/// Shared form widget used by both ConnectionSetupScreen and the connection settings dialog
class ConnectionSettingsForm extends StatefulWidget {
  final String saveButtonLabel;
  final VoidCallback onSaved;

  const ConnectionSettingsForm({super.key, required this.saveButtonLabel, required this.onSaved});

  @override
  State<ConnectionSettingsForm> createState() => _ConnectionSettingsFormState();
}

class _ConnectionSettingsFormState extends State<ConnectionSettingsForm> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customProxyPortController = TextEditingController();

  bool _useTor = false;
  bool _useSsl = false;
  bool _hasTested = false;
  bool _connectionTestIsLoading = false;
  bool _connectionSuccess = false;
  TorConnectionStatus _torStatus = TorService.sharedInstance.status;
  Timer? _torStatusTimer;

  @override
  void initState() {
    super.initState();
    _loadPersistedConnection();
  }

  @override
  void dispose() {
    _torStatusTimer?.cancel();
    _addressController.dispose();
    _customProxyPortController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedConnection() async {
    final wallet = Provider.of<WalletModel>(context, listen: false);
    final conn = await wallet.getPersistedConnection();

    setState(() {
      _addressController.text = conn.address;
      _customProxyPortController.text = conn.proxyPort;
      _useTor = conn.useTor;
      _useSsl = conn.useSsl;
    });

    if (conn.useTor && TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
      _pollTorStatus();
    }
  }

  String _cleanAddress(String value) {
    return value.trim().replaceAll(r'https?:\/\/', '');
  }

  bool _isValidConnectionAddress(String value) {
    final connectionUrlRegex = RegExp(
      [
        r'(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}(?::\d{1,5})?$',
        r'[a-z2-7]{56}.onion(:\d{1,5})?$',
        r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(?::\d{1,5})?$',
      ].join('|'),
    );

    return connectionUrlRegex.hasMatch(value.replaceAll(r'https?:\/\/', ''));
  }

  Future<void> _scanQrCode() async {
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result != null && result is String) {
      final scannedAddress = result.trim();
      if (_isValidConnectionAddress(scannedAddress)) {
        _addressController.text = scannedAddress;
        _onAddressChange(scannedAddress);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.connectionSetupInvalidQrCode)));
        }
      }
    }
  }

  void _onAddressChange(String value) {
    value = _cleanAddress(value);

    final ipAddressRegex = RegExp(
      r'(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}$',
    );
    final onionAddressRegex = RegExp(r'[a-z2-7]{56}.onion(:\d{1,5})?$');
    final domainAddressRegex = RegExp(
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(?::\d{1,5})?$',
    );

    var useTor = false;
    var useSsl = false;

    if (ipAddressRegex.hasMatch(value)) {
      useTor = false;
      useSsl = false;
    } else if (onionAddressRegex.hasMatch(value)) {
      useSsl = false;
      useTor = true;
    } else if (domainAddressRegex.hasMatch(value)) {
      useTor = false;
      useSsl = true;
    }

    if (value.startsWith('https://')) {
      useSsl = true;
    } else if (value.startsWith('http://')) {
      useSsl = false;
    }

    _setUseSsl(useSsl);
    _setUseTor(useTor);

    setState(() {
      _hasTested = false;
    });
  }

  void _onProxyPortChange(String value) {
    setState(() {
      _hasTested = false;
    });
  }

  void _setUseTor(bool? value) {
    if (TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      log(LogLevel.info, 'Tor is disabled. Not setting useTor to true.');
      value = false;
    }

    setState(() {
      _useTor = value ?? false;
      _useSsl = value == true ? false : _useSsl;
      _hasTested = false;
    });

    if (value == true) {
      _customProxyPortController.text = '';

      if (TorSettingsService.sharedInstance.torMode == TorMode.builtIn &&
          TorService.sharedInstance.status != TorConnectionStatus.connected) {
        _pollTorStatus();
      }
    }
  }

  void _pollTorStatus() {
    _torStatusTimer?.cancel();
    _torStatusTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      final status = TorService.sharedInstance.status;
      if (status == TorConnectionStatus.connected) {
        setState(() {
          _torStatus = status;
        });
        timer.cancel();
      }
    });
  }

  void _setUseSsl(bool? value) {
    setState(() {
      _useSsl = value ?? false;
      _hasTested = false;
    });
  }

  Future _testConnection() async {
    final i18n = AppLocalizations.of(context)!;
    final proto = _useSsl ? 'https' : 'http';
    final daemonAddress = _cleanAddress(_addressController.text);
    final customProxyPort = _customProxyPortController.text;

    // Handle demo mode
    if (isDemoMode) {
      if (daemonAddress == 'demo') {
        setState(() {
          _hasTested = true;
          _connectionSuccess = true;
        });
        return;
      }
    }

    setState(() {
      _hasTested = true;
      _connectionTestIsLoading = true;
    });

    final url = '$proto://$daemonAddress/get_address_info';

    try {
      if (_useTor) {
        if (!mounted) {
          return;
        }

        final torSettings = TorSettingsService.sharedInstance;

        if (torSettings.torMode == TorMode.disabled) {
          // show error toast
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.connectionSetupTorDisabledError)));
          return;
        }

        final proxyInfo = await torSettings.getProxy();

        final response = await makeSocksHttpRequest(
          'POST',
          url,
          proxyInfo!,
        ).timeout(Duration(seconds: 20));

        setState(() {
          _connectionSuccess = response.statusCode == HttpStatus.internalServerError;
        });
      } else {
        var httpClient = HttpClient();

        if (customProxyPort != '') {
          httpClient = httpClient
            ..findProxy = (uri) {
              return "PROXY localhost:$customProxyPort";
            };
        }

        final request = await httpClient.postUrl(Uri.parse(url));
        final response = await request.close().timeout(Duration(seconds: 10));

        setState(() {
          _connectionSuccess = response.statusCode == HttpStatus.internalServerError;
        });
      }
    } catch (error) {
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      setState(() {
        _connectionTestIsLoading = false;
      });
    }
  }

  Future<void> _saveConnection() async {
    final daemonAddress = _cleanAddress(_addressController.text);
    final proxyAddress = _customProxyPortController.text;

    final wallet = Provider.of<WalletModel>(context, listen: false);

    wallet.setConnection(
      address: daemonAddress,
      proxyPort: proxyAddress,
      useTor: _useTor,
      useSsl: _useSsl,
    );

    await wallet.persistCurrentConnection();

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final torMode = TorSettingsService.sharedInstance.torMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        TextFormField(
          controller: _addressController,
          onChanged: _onAddressChange,
          decoration: InputDecoration(
            labelText: i18n.address,
            hintText: i18n.connectionSetupAddressHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (Platform.isAndroid || Platform.isIOS)
                  IconButton(onPressed: _scanQrCode, icon: Icon(Icons.qr_code)),
                if (_hasTested && !_connectionTestIsLoading)
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      _connectionSuccess ? Icons.check : Icons.cancel_outlined,
                      color: _connectionSuccess ? Colors.teal : Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          keyboardType: TextInputType.url,
        ),
        TextFormField(
          controller: _customProxyPortController,
          onChanged: _onProxyPortChange,
          enabled: !_useTor,
          decoration: InputDecoration(
            labelText: i18n.connectionSetupProxyPortLabel,
            hintText: i18n.connectionSetupProxyPortHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        ),
        CheckboxListTile(
          title: Text(i18n.connectionSetupUseTorLabel),
          value: _useTor,
          onChanged: _useSsl || torMode == TorMode.disabled ? null : _setUseTor,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: Text(i18n.connectionSetupUseSslLabel),
          value: _useSsl,
          onChanged: !_useTor ? _setUseSsl : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_useTor)
          Text(
            torMode == TorMode.builtIn
                ? i18n.connectionSetupUsingInternalTor
                : i18n.connectionSetupUsingExternalTor(
                    '127.0.0.1:${TorSettingsService.sharedInstance.socksPort}',
                  ),
            style: TextStyle(color: Colors.purple, fontStyle: FontStyle.italic),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            if (_useTor &&
                torMode == TorMode.builtIn &&
                _torStatus != TorConnectionStatus.connected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text(i18n.connectionSetupStartingTor),
                ],
              )
            else
              TextButton.icon(
                label: Text(i18n.connectionSetupTestConnectionButton),
                onPressed: () => _testConnection(),
                icon: !_connectionTestIsLoading
                    ? Icon(Icons.network_check)
                    : SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
            if (_connectionSuccess && _hasTested && !_connectionTestIsLoading)
              FilledButton.icon(onPressed: _saveConnection, label: Text(widget.saveButtonLabel)),
          ],
        ),
      ],
    );
  }
}
