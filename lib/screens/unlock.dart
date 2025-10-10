import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'package:monero_light_wallet/l10n/app_localizations.dart';
import 'package:monero_light_wallet/util/logging.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  @override
  void initState() {
    super.initState();
    _promptUnlock();
  }

  Future<void> _promptUnlock() async {
    final auth = LocalAuthentication();

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock wallet',
        options: AuthenticationOptions(
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (didAuthenticate) {
        if (mounted) Navigator.pushReplacementNamed(context, '/wallet_home');
      }
    } catch (error) {
      log(LogLevel.error, 'Unable to authenticate: ${error.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to authenticate.')));
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Monero Light Wallet')),
      body: SafeArea(
        child: Center(
          child: FilledButton.icon(
            onPressed: _promptUnlock,
            label: Text(i18n.unlockButton),
            icon: Icon(Icons.lock_open),
          ),
        ),
      ),
    );
  }
}
