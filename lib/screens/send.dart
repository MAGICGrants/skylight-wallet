import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monero_light_wallet/models/wallet_model.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  String _destinationAddress = '';
  double _amount = 0;

  String _destinationAddressError = '';

  void _send() {
    setState(() {
      _isLoading = true;
    });

    _destinationAddressError = '';
    String resolvedDestinationAddress = '';

    final wallet = Provider.of<WalletModel>(context, listen: false);
    final domainRegex = RegExp(
      r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$',
    );

    if (domainRegex.hasMatch(_destinationAddress)) {
      // check for openalias
      resolvedDestinationAddress = wallet.resolveOpenAlias(_destinationAddress);

      if (resolvedDestinationAddress == '') {
        setState(() {
          _destinationAddressError = 'Could not resolve OpenAlias.';
          _isLoading = false;
        });
        return;
      }
    } else if (wallet.wallet.addressValid(_destinationAddress, 0)) {
      // check for address
      setState(() {
        resolvedDestinationAddress = _destinationAddress;
        _isLoading = false;
      });
    } else {
      setState(() {
        _destinationAddressError = 'Invalid address.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    wallet.send(resolvedDestinationAddress, _amount);
    Navigator.pushNamed(context, '/wallet_home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Text('Send', style: Theme.of(context).textTheme.headlineMedium),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Address',
                  border: OutlineInputBorder(),
                  errorText: _destinationAddressError != ''
                      ? _destinationAddressError
                      : null,
                ),
                onChanged: (text) {
                  setState(() {
                    _destinationAddress = text;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?')),
                ],
                decoration: InputDecoration(
                  hintText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) {
                  setState(() {
                    _amount = double.parse(text);
                  });
                },
              ),
            ),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/wallet_home'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _send,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!_isLoading)
                        AnimatedOpacity(
                          opacity: _isLoading ? 0.0 : 1.0,
                          duration: Duration(milliseconds: 300),
                          child: Text('Send'),
                        ),
                      if (_isLoading)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
