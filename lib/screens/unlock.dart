import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/floating_bob.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  static bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDesktop) _promptUnlock();
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
        showBrandToast(context, i18n.unlockUnableToAuthError);
      }
    }
  }

  Future<void> _unlockWithPassword() async {
    final i18n = AppLocalizations.of(context)!;
    if (_passwordController.text.isEmpty) {
      setState(() => _error = i18n.fieldEmptyError);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await unlockWithPassword(context, _passwordController.text);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = i18n.unlockIncorrectPasswordError;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return UnlockView(
      logo: FloatingBob(child: SvgPicture.asset('assets/logo_nobg.svg', width: 100, height: 100)),
      labels: UnlockLabels(
        title: i18n.unlockTitle,
        passwordHint: i18n.unlockPasswordHint,
        unlockButton: i18n.unlockButton,
      ),
      isDesktop: _isDesktop,
      passwordController: _passwordController,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      error: _error,
      loading: _isLoading,
      onUnlockPassword: _unlockWithPassword,
      onUnlockBiometric: _promptUnlock,
    );
  }
}
