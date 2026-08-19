import 'dart:io';
import 'package:flutter/material.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/widgets/loading_button.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;

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
    final i18n = AppLocalizations.of(context)!;
    final result = await BiometricAuth.authenticate(reason: i18n.unlockReason);

    // Auto-prompted with a password field right there: stay silent on a decline
    // (the user chose to type instead), report only a real error.
    if (result == BiometricAuthResult.authenticated) {
      if (mounted) Navigator.pushReplacementNamed(context, '/wallet_home');
    } else if (result == BiometricAuthResult.error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.unlockUnableToAuthError)));
      }
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
      await unlockWithPassword(context, enteredPassword);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (Route<dynamic> route) => false);
      }
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
      appBar: AppBar(title: Text('Skylight Monero Wallet')),
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
                              textInputAction: TextInputAction.done,
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
