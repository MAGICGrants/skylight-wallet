import 'dart:io';

import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/util/logging.dart';
import 'package:skylight_wallet/util/secure_clipboard.dart';
import 'package:skylight_wallet/util/wallet.dart';
import 'package:skylight_wallet/util/wallet_password.dart';
import 'package:skylight_wallet/wallets/coins/monero/legacy_monero_wallet.dart';

/// Shown on launch when a v1 (legacy/polyseed) wallet file is found. Explains
/// that these seeds are no longer supported, lets the user reveal the old seed
/// to back it up, and delete the unsupported wallet (→ welcome).
class LegacyWalletScreen extends StatefulWidget {
  const LegacyWalletScreen({super.key});

  @override
  State<LegacyWalletScreen> createState() => _LegacyWalletScreenState();
}

class _LegacyWalletScreenState extends State<LegacyWalletScreen> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _seed;

  bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  // v1 stored wallet state under these global (un-namespaced) keys.
  static const _v1Keys = [
    'connectionAddress',
    'connectionProxyPort',
    'connectionUseTor',
    'connectionUseSsl',
    'walletRestoreHeight',
    'txHistoryCount',
    'serverSupportsSubaddresses',
    'unusedSubaddressIndex',
    'unusedSubaddressIndexIsSupported',
  ];

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _resolvePassword(AppLocalizations i18n) async {
    if (_isDesktop) {
      final entered = _passwordController.text;
      if (entered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.fieldEmptyError)));
        return null;
      }
      return entered;
    }
    return getMobileWalletPassword();
  }

  Future<void> _showSeed() async {
    if (_busy) return;
    final i18n = AppLocalizations.of(context)!;
    setState(() => _busy = true);

    final password = await _resolvePassword(i18n);
    if (password == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    final legacy = LegacyMoneroWallet();
    try {
      await legacy.openExisting(password: password);
      final seed = legacy.seedPhrase();
      if (!mounted) return;
      setState(() {
        _seed = seed;
        _busy = false;
      });
    } catch (error) {
      log(LogLevel.error, 'Legacy wallet open failed: $error');
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.legacyError)));
      }
    } finally {
      legacy.dispose();
    }
  }

  void _showDeleteWalletDialog() {
    final i18n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth.clamp(0.0, 500.0);

        return AlertDialog(
          constraints: BoxConstraints.tightFor(width: dialogWidth),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          title: Row(
            spacing: 6,
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              Text(i18n.settingsDeleteWalletButton),
            ],
          ),
          content: Text(i18n.settingsDeleteWalletDialogText),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _delete();
              },
              icon: Icon(Icons.delete_forever),
              label: Text(i18n.settingsDeleteWalletDialogDeleteButton),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.cancel),
              label: Text(i18n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      final file = File(await getLegacyWalletPath());
      if (await file.exists()) await file.delete();
      await deleteMobileWalletPassword();
      for (final k in _v1Keys) {
        await SharedPreferencesService.remove(k);
      }
    } catch (error) {
      log(LogLevel.error, 'Legacy wallet delete failed: $error');
    }
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Skylight Wallet')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  Text(
                    i18n.legacyTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    i18n.legacyDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_isDesktop && _seed == null)
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: i18n.unlockPasswordLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                  if (_seed != null) ...[
                    TextField(
                      readOnly: true,
                      maxLines: null,
                      controller: TextEditingController(text: _seed),
                      decoration: InputDecoration(
                        labelText: i18n.legacySeedLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () => SecureClipboard.copy(_seed!),
                        ),
                      ),
                    ),
                    // Delete only after the user has seen (and can back up) the seed.
                    TextButton.icon(
                      onPressed: _busy ? null : _showDeleteWalletDialog,
                      label: Text(i18n.settingsDeleteWalletButton),
                      icon: Icon(Icons.delete),
                      style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Colors.red)),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _showSeed,
                      icon: Icon(Icons.visibility),
                      label: Text(i18n.legacyShowSeedButton),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
