import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';

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
  String? _biometricLabel; // resolved per device on iOS (Face ID vs Touch ID)
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guarded: didChangeDependencies re-fires whenever an inherited dependency
    // changes -- a locale or theme flip, for instance -- and _promptUnlock
    // reads Localizations. Without this the biometric sheet is raised a second
    // time on top of the first, which iOS resolves by cancelling both.
    if (_started || _isDesktop) return;
    _started = true;
    _resolveBiometricLabel();
    _promptUnlock();
  }

  /// iOS labels the affordance by the device's biometric (Face ID / Touch ID);
  /// Android and desktop keep the generic "Unlock".
  Future<void> _resolveBiometricLabel() async {
    if (!Platform.isIOS) return;
    final i18n = AppLocalizations.of(context)!;
    try {
      final types = await LocalAuthentication().getAvailableBiometrics();
      final label = types.contains(BiometricType.face)
          ? i18n.unlockWithFaceId
          : i18n.unlockWithTouchId;
      if (mounted) setState(() => _biometricLabel = label);
    } catch (_) {
      // Leave the generic label.
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
      biometricLabel: _biometricLabel,
      onUnlockPassword: _unlockWithPassword,
      onUnlockBiometric: _promptUnlock,
    );
  }
}
