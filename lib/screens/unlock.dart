import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  static bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;
  String? _biometricLabel; // resolved per device on iOS (Face ID vs Touch ID)
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  void _unlockDone(WalletManager manager) {
    // A relock pushes this screen over the existing stack, so pop back to the
    // screen the user left. A cold start has this as the base route (nothing to
    // pop) — go to home instead.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil('/wallet_home', (route) => false);
    }
    manager.openWalletFilesAndSync();
  }

  Future<void> _promptUnlock() async {
    final i18n = AppLocalizations.of(context)!;
    final result = await BiometricAuth.authenticate(reason: i18n.unlockReason);

    // Auto-prompted, so stay silent on a decline; report only a real error.
    if (result == BiometricAuthResult.failed) return;
    if (result == BiometricAuthResult.error) {
      _showError(i18n.unlockUnableToAuthError);
      return;
    }

    if (!mounted) return;
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (!await manager.loadMobileWalletPassword()) {
      log(LogLevel.error, 'Biometric auth succeeded but no stored wallet password');
      _showError(i18n.unlockUnableToAuthError);
      return;
    }
    if (mounted) _unlockDone(manager);
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
      final manager = Provider.of<WalletManager>(context, listen: false);
      manager.setWalletPassword(_passwordController.text);
      if (mounted) _unlockDone(manager);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = i18n.unlockIncorrectPasswordError;
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    // Block the system back button: this screen sits over the previous stack on
    // a relock, and backing out of it would reveal that screen unauthenticated.
    // Unlocking still pops programmatically from _unlockDone.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 3),
                Center(child: SvgPicture.asset('assets/spice-mark.svg', width: 84, height: 84)),
                const SizedBox(height: BrandSpacing.xl),
                Text(i18n.unlockLockedTitle, textAlign: TextAlign.center, style: BrandText.title),
                if (_isDesktop) ...[
                  const SizedBox(height: BrandSpacing.xl),
                  BrandTextField(
                    controller: _passwordController,
                    hint: i18n.unlockPasswordHint,
                    obscureText: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: BrandColors.inkMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: BrandSpacing.sm),
                    Text(_error!, style: BrandText.caption.copyWith(color: BrandColors.error)),
                  ],
                ],
                const Spacer(flex: 4),
                if (_isDesktop)
                  BrandButton(
                    label: i18n.unlockButton,
                    loading: _isLoading,
                    onPressed: _unlockWithPassword,
                  )
                else
                  BrandButton(
                    label: _biometricLabel ?? i18n.unlockButton,
                    icon: Icons.lock_outline,
                    onPressed: _promptUnlock,
                  ),
                const SizedBox(height: BrandSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
