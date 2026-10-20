import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/util/platform.dart' show typesWalletPassword;
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/floating_bob.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart' show AppSession;
import 'package:wallet_fhse/security_keys_ui.dart'
    show
        FhseLocalizations,
        reopenAfterAppLock,
        showAppLockRecoveryPhrase,
        waitForFullLock,
        walletNeedsSecurityKey;
import 'package:wallet_infra/wallet_infra.dart'
    show BiometricAuth, BiometricAuthResult, BoundToAnotherPcException;

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
    // Always asks (App Lock is always on); a device with no lock at all has
    // nothing to ask and passes, and Settings warns about it.
    final result = await BiometricAuth.confirmOwner(reason: i18n.unlockReason);

    // Auto-prompted: stay silent on a decline (the button asks again), report
    // only a real error, and offer the recovery phrase for it.
    if (result == BiometricAuthResult.authenticated) {
      // A full lock still closing the wallets decides what comes next.
      await waitForFullLock();
      if (!mounted) return;
      // With security keys on and the wallet closed, a key comes next.
      final needsKey = await walletNeedsSecurityKey(context);
      if (!mounted) return;
      // Otherwise the keystore password comes back (a relock dropped it) and,
      // after a full lock, the wallet opens again. Without one it stays shut.
      if (!needsKey && !await reopenAfterAppLock(context)) {
        if (mounted) {
          setState(() => _offerRecoveryPhrase = true);
          showBrandToast(context, i18n.unlockUnableToAuthError);
        }
        return;
      }
      if (mounted) _unlocked(needsKey: needsKey);
    } else if (result == BiometricAuthResult.error) {
      if (mounted) {
        setState(() => _offerRecoveryPhrase = true);
        showBrandToast(context, i18n.unlockUnableToAuthError);
      }
    }
  }

  /// The device could not confirm its owner: the recovery phrase opens the
  /// wallet instead (and stands in for a security key, when keys are on).
  Future<void> _useRecoveryPhrase() async {
    if (await showAppLockRecoveryPhrase(context) && mounted) _unlocked(needsKey: false);
  }

  /// Past App Lock. A key comes next when keys are on and the wallet is
  /// closed; otherwise this was the last lock ([AppSession]). A relock covers
  /// the screen the user left, and the app uncovers it; at a launch or after
  /// a full lock this is the base route, and home comes next.
  void _unlocked({required bool needsKey}) {
    if (needsKey) {
      final onKeyNeeded = widget.onKeyNeeded;
      if (onKeyNeeded != null) return onKeyNeeded();
      Navigator.of(context).pushNamedAndRemoveUntil('/security_key_unlock', (route) => false);
      return;
    }
    AppSession.markUnlocked();
    final onUnlocked = widget.onUnlocked;
    if (onUnlocked != null) return onUnlocked();
    Navigator.of(context).pushReplacementNamed('/wallet_home');
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
      // App Lock after a time without use: the wallet stayed open, so the
      // password is only checked again and the screen left comes back.
      final rechecked = await recheckPasswordIfOpen(context, _passwordController.text);
      if (rechecked != null) {
        if (!rechecked) throw Exception('Incorrect wallet password.');
        if (mounted) {
          _passwordController.clear();
          _unlocked(needsKey: false);
        }
        return;
      }
      if (!mounted) return;
      final needsKey = await unlockWithPassword(context, _passwordController.text);
      if (mounted) {
        if (widget.onUnlocked != null) return _unlocked(needsKey: needsKey);
        // No key to follow: the password was the last lock.
        if (!needsKey) AppSession.markUnlocked();
        Navigator.pushNamedAndRemoveUntil(
          context,
          needsKey ? '/security_key_unlock' : '/wallet_home',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _passwordController.clear();
        setState(() {
          // The files are bound to a PC whose TPM this one cannot use.
          _error = e is BoundToAnotherPcException
              ? FhseLocalizations.of(context).unlockBoundToAnotherPc
              : i18n.unlockIncorrectPasswordError;
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
