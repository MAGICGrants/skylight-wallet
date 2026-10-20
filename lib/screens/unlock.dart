import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/platform.dart' show typesWalletPassword;
import 'package:skylight_wallet/widgets/floating_bob.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_fhse/security_keys_ui.dart'
    show
        AppLockUnlock,
        FhseLocalizations,
        showAppLockRecoveryPhrase,
        unlockAppLockWithDevice,
        unlockAppLockWithPassword;

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, this.onUnlocked, this.onKeyNeeded});

  /// Set when this is App Lock's cover over the screens the user left
  /// (`AppLockCover`), which has no route to pop: the app hides the cover.
  final VoidCallback? onUnlocked;

  /// The cover's way on when the wallet closed meanwhile and a security key
  /// comes next: the app replaces its stack with the key screen.
  final VoidCallback? onKeyNeeded;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  // The typed password at every launch (Linux, Windows); App Lock's device
  // prompt elsewhere, macOS included (Touch ID or the Mac's password).
  static bool get _isDesktop => typesWalletPassword;

  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;
  String? _biometricLabel; // resolved per device on iOS (Face ID vs Touch ID)
  bool _started = false;
  // The device could not confirm its owner (a lockout, say): the recovery
  // phrase is offered as the way in instead.
  bool _offerRecoveryPhrase = false;
  String _version = ''; // desktop footer status bar

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = 'Skylight Wallet v${info.version} · build ${info.buildNumber}');
      }
    });
  }

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
      // A passcode alone keeps the generic "Unlock".
      if (types.isEmpty) return;
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
    final outcome = await unlockAppLockWithDevice(context, reason: i18n.unlockReason);
    if (mounted) _show(outcome);
  }

  /// The device could not confirm its owner: the recovery phrase opens the
  /// wallet instead (and stands in for a security key, when keys are on).
  Future<void> _useRecoveryPhrase() async {
    if (await showAppLockRecoveryPhrase(context) && mounted) _show(AppLockUnlock.unlocked);
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
    final outcome = await unlockAppLockWithPassword(context, _passwordController.text);
    if (!mounted) return;
    _passwordController.clear();
    setState(() => _isLoading = false);
    _show(outcome);
  }

  /// Shows what App Lock's unlock decided (wallet_fhse's [AppLockUnlock]):
  /// where to go, or what to say.
  void _show(AppLockUnlock outcome) {
    final i18n = AppLocalizations.of(context)!;
    switch (outcome) {
      case AppLockUnlock.unlocked:
        // A relock covers the screen the user left, and the app uncovers it.
        // At a launch or after a full lock this is the base route: home next.
        final onUnlocked = widget.onUnlocked;
        if (onUnlocked != null) return onUnlocked();
        Navigator.of(context).pushNamedAndRemoveUntil('/wallet_home', (route) => false);
      case AppLockUnlock.needsKey:
        final onKeyNeeded = widget.onKeyNeeded;
        if (onKeyNeeded != null) return onKeyNeeded();
        Navigator.of(context).pushNamedAndRemoveUntil('/security_key_unlock', (route) => false);
      case AppLockUnlock.declined:
        // Auto-prompted: stay quiet; the button asks again.
        break;
      case AppLockUnlock.failed:
        if (typesWalletPassword) {
          setState(() => _error = i18n.unlockUnableToAuthError);
          return;
        }
        setState(() => _offerRecoveryPhrase = true);
        showBrandToast(context, i18n.unlockUnableToAuthError);
      case AppLockUnlock.wrongPassword:
        setState(() => _error = i18n.unlockIncorrectPasswordError);
      case AppLockUnlock.boundToAnotherPc:
        setState(() => _error = FhseLocalizations.of(context).unlockBoundToAnotherPc);
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
      version: _version.isEmpty ? null : _version,
      passwordController: _passwordController,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      error: _error,
      loading: _isLoading,
      biometricLabel: _biometricLabel,
      onUnlockPassword: _unlockWithPassword,
      onUnlockBiometric: _promptUnlock,
      recoveryLabel: _offerRecoveryPhrase
          ? FhseLocalizations.of(context).securityKeyUseRecoveryPhrase
          : null,
      onUseRecoveryPhrase: _useRecoveryPhrase,
    );
  }
}
