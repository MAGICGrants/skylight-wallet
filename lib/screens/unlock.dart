import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/wallets/wallet_manager.dart';
import 'package:spice_wallet/widgets/loading_button.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      _promptUnlock();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _promptUnlock() async {
    final auth = LocalAuthentication();
    final i18n = AppLocalizations.of(context)!;

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: i18n.unlockReason,
        options: AuthenticationOptions(useErrorDialogs: true, sensitiveTransaction: true),
      );

      if (!didAuthenticate) return;

      if (!mounted) return;
      final manager = Provider.of<WalletManager>(context, listen: false);
      final loaded = await manager.loadMobileWalletPassword();
      if (!loaded) {
        log(LogLevel.error, 'Biometric auth succeeded but no stored wallet password');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.unlockUnableToAuthError)));
        }
        return;
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
      }
      manager.openWalletFilesAndSync();
    } catch (error) {
      log(LogLevel.error, 'Unable to authenticate: ${error.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.unlockUnableToAuthError)));
      }
      return;
    }
  }

  Future<void> _unlockWithPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enteredPassword = _passwordController.text;
      final manager = Provider.of<WalletManager>(context, listen: false);

      manager.setWalletPassword(enteredPassword);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
      }

      manager.openWalletFilesAndSync();
    } catch (e) {
      if (mounted) {
        final i18n = AppLocalizations.of(context)!;

        setState(() {
          _errorMessage = i18n.unlockIncorrectPasswordError;
          _isLoading = false;
        });
      }
    }
  }

  String? _validatePasswordField(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)!.fieldEmptyError;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    return Scaffold(
      appBar: AppBar(title: Text('Spice Wallet')),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            padding: EdgeInsets.all(20),
            child: isDesktop
                ? Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 20,
                      children: [
                        Column(
                          spacing: 10,
                          children: [
                            Text(
                              i18n.unlockTitle,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              i18n.unlockDescription,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        Column(
                          spacing: 15,
                          children: [
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: _validatePasswordField,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: i18n.unlockPasswordLabel,
                                hintText: i18n.unlockPasswordHint,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                errorText: _errorMessage,
                              ),
                              onFieldSubmitted: (_) => _unlockWithPassword(),
                            ),
                            LoadingButton(
                              isLoading: _isLoading,
                              onPressed: _unlockWithPassword,
                              label: i18n.unlockButton,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _promptUnlock,
                    label: Text(i18n.unlockButton),
                    icon: Icon(Icons.lock_open),
                  ),
          ),
        ),
      ),
    );
  }
}
