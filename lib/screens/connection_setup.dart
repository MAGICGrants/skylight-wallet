import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylight_wallet/util/socks_http.dart';
import 'package:provider/provider.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/models/wallet_model.dart';
import 'package:skylight_wallet/services/tor_service.dart';

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customProxyPortController =
      TextEditingController();
  bool _useTor = false;
  bool _useSsl = false;
  bool _hasTested = false;
  bool _isLoading = false;
  bool _connectionSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedConnection();
  }

  @override
  void dispose() {
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
  }

  void _setUseTor(bool? newValue) {
    setState(() {
      _useTor = newValue ?? false;
    });

    if (newValue == true) {
      _customProxyPortController.text = '';
    }
  }

  Future _testConnection() async {
    final proto = _useSsl ? 'https' : 'http';
    final daemonAddress = _addressController.text;
    final customProxyPort = _customProxyPortController.text;
    String torProxyPort = '';

    if (_useTor) {
      await TorService.sharedInstance.start();
      await TorService.sharedInstance.waitUntilConnected();
      torProxyPort = TorService.sharedInstance.getProxyInfo().port.toString();
    }

    String proxyPort = torProxyPort != '' ? torProxyPort : customProxyPort;

    setState(() {
      _hasTested = true;
    });

    final url = '$proto://$daemonAddress/get_address_info';

    setState(() {
      _isLoading = true;
    });

    try {
      if (_useTor) {
        final proxyInfo = TorService.sharedInstance.getProxyInfo();
        final response = await makeSocksHttpRequest('POST', url, proxyInfo);

        setState(() {
          _connectionSuccess =
              response.statusCode == HttpStatus.internalServerError;
        });
      } else {
        var httpClient = HttpClient();

        if (proxyPort != '') {
          httpClient = httpClient
            ..findProxy = (uri) {
              return "PROXY localhost:$proxyPort";
            };
        }

        final request = await httpClient.postUrl(Uri.parse(url));
        final response = await request.close().timeout(Duration(seconds: 10));

        setState(() {
          _connectionSuccess =
              response.statusCode == HttpStatus.internalServerError;
        });
      }
    } catch (error) {
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveConnection() {
    final daemonAddress = _addressController.text;
    final proxyAddress = _customProxyPortController.text;

    final wallet = Provider.of<WalletModel>(context, listen: false);

    wallet.setConnection(
      address: daemonAddress,
      proxyPort: proxyAddress,
      useTor: _useTor,
      useSsl: _useSsl,
    );

    wallet.persistCurrentConnection();
    Navigator.pushNamed(context, '/create_wallet');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
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
                    i18n.connectionSetupTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    i18n.connectionSetupDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              Column(
                spacing: 10,
                children: [
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: i18n.address,
                      hintText: i18n.connectionSetupAddressHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: _hasTested && !_isLoading
                          ? Icon(
                              _connectionSuccess
                                  ? Icons.check
                                  : Icons.cancel_outlined,
                            )
                          : null,
                      suffixIconColor: _connectionSuccess
                          ? Colors.teal
                          : Colors.red,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  if (!_useTor)
                    TextFormField(
                      controller: _customProxyPortController,
                      decoration: InputDecoration(
                        labelText: i18n.connectionSetupProxyPortLabel,
                        hintText: i18n.connectionSetupProxyPortHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  CheckboxListTile(
                    title: Text(i18n.connectionSetupUseTorLabel),
                    value: _useTor,
                    onChanged: _setUseTor,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  CheckboxListTile(
                    title: Text(i18n.connectionSetupUseSslLabel),
                    value: _useSsl,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _useSsl = newValue ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => _testConnection(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!_isLoading)
                              AnimatedOpacity(
                                opacity: _isLoading ? 0.0 : 1.0,
                                duration: Duration(milliseconds: 300),
                                child: Text(
                                  i18n.connectionSetupTestConnectionButton,
                                ),
                              ),
                            if (_isLoading)
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_connectionSuccess)
                        FilledButton(
                          onPressed: _saveConnection,
                          child: Text(i18n.connectionSetupContinueButton),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
