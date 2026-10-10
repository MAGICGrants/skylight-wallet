import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wallet_fhse/wallet_fhse.dart'
    show
        FhseVaultException,
        FhseVaultFailure,
        KeyVerification,
        SecurityKeyAuthenticator,
        SecurityKeyRecord;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/services/security_key_service.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// A security-key or vault failure as one sentence for the user, or null when
/// there is nothing to say (the user cancelled).
String? securityKeyErrorMessage(AppLocalizations i18n, Object error) {
  if (error is SecurityKeyException) {
    return switch (error.failure) {
      SecurityKeyFailure.cancelled => null,
      SecurityKeyFailure.pinInvalid =>
        error.retries == null
            ? i18n.securityKeysErrorPinInvalidUnknown
            : i18n.securityKeysErrorPinInvalid(error.retries!),
      SecurityKeyFailure.pinBlocked => i18n.securityKeysErrorPinBlocked,
      SecurityKeyFailure.pinAuthBlocked => i18n.securityKeysErrorPinAuthBlocked,
      SecurityKeyFailure.pinPolicy => i18n.securityKeysErrorPinPolicy,
      SecurityKeyFailure.pinChangeRequired => i18n.securityKeysErrorPinChangeRequired,
      SecurityKeyFailure.uvInvalid =>
        error.retries == null
            ? i18n.securityKeysErrorUvInvalidUnknown
            : i18n.securityKeysErrorUvInvalid(error.retries!),
      SecurityKeyFailure.uvBlocked => i18n.securityKeysErrorUvBlocked,
      SecurityKeyFailure.uvNotConfigured => i18n.securityKeysErrorUvNotConfigured,
      SecurityKeyFailure.differentKey => i18n.securityKeysErrorDifferentKey,
      SecurityKeyFailure.noCredentials => i18n.securityKeysErrorNotEnrolled,
      SecurityKeyFailure.credentialExcluded => i18n.securityKeysErrorAlreadyAdded,
      SecurityKeyFailure.unsupported => i18n.securityKeysErrorUnsupported(error.message ?? ''),
      SecurityKeyFailure.timeout => i18n.securityKeysErrorTimeout,
      SecurityKeyFailure.transport => i18n.securityKeysErrorTransport,
      _ => i18n.securityKeysErrorGeneric(error.message ?? error.failure.name),
    };
  }
  if (error is FhseVaultException) {
    return switch (error.reason) {
      FhseVaultFailure.keyNotEnrolled => i18n.securityKeysErrorNotEnrolled,
      FhseVaultFailure.keyAlreadyAdded => i18n.securityKeysErrorAlreadyAdded,
      FhseVaultFailure.wrongRecoveryPhrase => i18n.securityKeyRecoveryWrongPhrase,
      FhseVaultFailure.recoveryNotPossible => i18n.securityKeyRecoveryNotPossible,
      _ => i18n.securityKeysErrorGeneric(error.reason.name),
    };
  }
  return i18n.securityKeysErrorGeneric(error.runtimeType.toString());
}

enum _Step { connect, pin, newPin, confirm, name }

/// The steps of using a security key, in the order a browser's security-key
/// prompt takes them:
///
/// 1. **Connect.** Plug the key in and touch it, or hold it to the phone.
/// 2. **Verify.** The key's PIN, or a new one if it has none. A YubiKey Bio
///    with a fingerprint skips this; its sensor verifies in the next step.
/// 3. **Confirm.** Touch the key again: once to unlock, twice to add a key
///    (one touch creates the credential, the other reads its secret).
/// 4. **Name** (adding only).
///
/// The app draws these itself: FHSE needs raw CTAP2, which the system passkey
/// sheets do not offer (see [SecurityKeyService]). The prompts follow what the
/// key reports while it waits ([SecurityKeyService.status]), so "touch your
/// key" shows when the key is actually blinking.
class SecurityKeyFlow extends StatefulWidget {
  const SecurityKeyFlow({
    super.key,
    required this.enrolling,
    required this.useKey,
    required this.onDone,
    this.registeredKeys,
    this.rename,
    this.defaultName,
    this.large = false,
    this.autoStart,
  });

  /// Adding a key (two touches, then a name) rather than unlocking (one).
  final bool enrolling;

  /// The work once the user is verified: enrolls the key and returns its
  /// record, or unlocks with it and returns null. [key] is held to the key
  /// the user touched in the first step.
  final Future<SecurityKeyRecord?> Function(
    KeyVerification verification,
    SecurityKeyAuthenticator key,
  )
  useKey;

  /// The keys already registered (for this wallet, or in this setup). Their
  /// serial numbers tell the first step which key was touched, before any
  /// PIN: unlocking names it, adding refuses one already there.
  final Future<List<SecurityKeyRecord>> Function()? registeredKeys;

  /// Names the key just added, after its touches.
  final Future<void> Function(SecurityKeyRecord record, String name)? rename;
  final String? defaultName;

  final VoidCallback onDone;

  /// Full-screen type sizes (the unlock screen) rather than a sheet's.
  final bool large;

  /// Start waiting for a key straight away. Defaults to Android, where that
  /// is silent; on iOS it raises the NFC sheet, so it waits for a tap.
  final bool? autoStart;

  @override
  State<SecurityKeyFlow> createState() => _SecurityKeyFlowState();
}

class _SecurityKeyFlowState extends State<SecurityKeyFlow> {
  final _service = SecurityKeyService.instance;
  late final StreamSubscription<SecurityKeyStatus> _statusSub;

  final _pin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  late final _name = TextEditingController(text: widget.defaultName ?? '');

  _Step _step = _Step.connect;
  SecurityKeyInfo? _info;
  SecurityKeyStatus? _status;
  KeyVerification? _verification;
  SecurityKeyRecord? _record;

  /// The registered key that was touched, found by its serial number.
  SecurityKeyRecord? _known;
  bool _busy = false;
  bool _started = false;
  bool _obscure = true;

  /// The sensor said no for good this time (locked, or no fingerprint), so
  /// the PIN is the only way on with this key.
  bool _fingerprintOff = false;
  int _touches = 0;
  String? _error;

  bool get _usingFingerprint => _verification?.isBuiltIn ?? false;

  bool get _canUseFingerprint => !_fingerprintOff && (_info?.canUseFingerprint ?? false);

  @override
  void initState() {
    super.initState();
    _statusSub = _service.status.listen(_onStatus);
    if (widget.autoStart ?? Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connect();
      });
    }
  }

  @override
  void dispose() {
    _statusSub.cancel();
    if (_busy) _service.cancel().catchError((Object _) {});
    for (final c in [_pin, _newPin, _confirmPin, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStatus(SecurityKeyStatus status) {
    if (!_busy || !mounted || status == _status) return;
    setState(() {
      final waiting =
          status == SecurityKeyStatus.touchNeeded || status == SecurityKeyStatus.fingerprintNeeded;
      if (waiting && _step == _Step.confirm) _touches++;
      _status = status;
    });
  }

  void _begin(_Step step) => setState(() {
    _step = step;
    _busy = true;
    _started = true;
    _error = null;
    _status = null;
    _touches = 0;
  });

  // ----- Steps -----

  Future<void> _connect() async {
    _begin(_Step.connect);
    _verification = null;
    _known = null;
    try {
      final info = await _service.inspect(touch: true);
      final registered = await _registered();
      if (!mounted) return;
      final known = info.serial == null
          ? null
          : registered.where((r) => r.serial == info.serial).firstOrNull;
      final problem = _problemWith(info, known: known, registered: registered);
      if (problem != null) return _stop(_Step.connect, problem);
      _info = info;
      _known = known;
      _fingerprintOff = false;
      if (_canUseFingerprint) return _confirm(const KeyVerification.builtIn());
      _pin.clear();
      _newPin.clear();
      _confirmPin.clear();
      _stop(info.pinSet ? _Step.pin : _Step.newPin);
    } catch (e) {
      _fail(e);
    }
  }

  Future<List<SecurityKeyRecord>> _registered() async {
    try {
      return await widget.registeredKeys?.call() ?? const [];
    } catch (_) {
      // Only a convenience: the key itself still decides.
      return const [];
    }
  }

  /// Why this key cannot go on, before any PIN is asked for.
  String? _problemWith(
    SecurityKeyInfo info, {
    required SecurityKeyRecord? known,
    required List<SecurityKeyRecord> registered,
  }) {
    final i18n = AppLocalizations.of(context)!;
    if (!info.supportsHmacSecret || !info.supportsCredProtect) {
      return i18n.securityKeysErrorKeyUnsupported;
    }
    if (widget.enrolling && known != null) return i18n.securityKeysErrorAlreadyAdded;
    // Unlocking with a key whose serial matches none of the registered ones.
    // Only certain when every registered key has a serial on file.
    if (!widget.enrolling &&
        info.serial != null &&
        known == null &&
        registered.isNotEmpty &&
        registered.every((r) => r.serial != null)) {
      return i18n.securityKeysErrorNotEnrolled;
    }
    if (info.forcePinChange) return i18n.securityKeysErrorPinChangeRequired;
    if (info.pinSet && info.pinRetries == 0) return i18n.securityKeysErrorPinBlocked;
    // Every enrolled credential needs the PIN, so a key without one holds none.
    if (!widget.enrolling && !info.pinSet) return i18n.securityKeysErrorNotEnrolled;
    return null;
  }

  void _submitPin() {
    if (_pin.text.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.fieldEmptyError);
      return;
    }
    _confirm(KeyVerification.pin(_pin.text));
  }

  Future<void> _setPin() async {
    final i18n = AppLocalizations.of(context)!;
    final pin = _newPin.text;
    final minLength = _info?.minPinLength ?? 4;
    if (pin.runes.length < minLength) {
      setState(() => _error = i18n.securityKeysPinTooShortCount(minLength));
      return;
    }
    if (pin != _confirmPin.text) {
      setState(() => _error = i18n.securityKeysPinMismatch);
      return;
    }
    _begin(_Step.newPin);
    try {
      await _service.setPin(pin, expectSerial: _info?.serial);
      if (!mounted) return;
      _newPin.clear();
      _confirmPin.clear();
      await _confirm(KeyVerification.pin(pin));
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _confirm(KeyVerification verification) async {
    _verification = verification;
    _begin(_Step.confirm);
    try {
      final record = await widget.useKey(verification, _service.expecting(_info?.serial));
      if (!mounted) return;
      _pin.clear();
      if (widget.enrolling && record != null) {
        _record = record;
        return _stop(_Step.name);
      }
      setState(() => _busy = false);
      widget.onDone();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _saveName() async {
    final record = _record;
    final name = _name.text.trim();
    if (record != null && name.isNotEmpty && name != record.name) {
      setState(() => _busy = true);
      try {
        await widget.rename?.call(record, name);
      } catch (_) {
        // The key is added either way; a failed rename keeps the default.
      }
      if (!mounted) return;
    }
    widget.onDone();
  }

  void _stop(_Step step, [String? error]) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _busy = false;
      _status = null;
      _touches = 0;
      _error = error;
    });
  }

  /// Where each failure leaves the user: a wrong PIN back at the PIN, a
  /// fingerprint miss ready to try again, anything about the key itself back
  /// at connecting a key.
  void _fail(Object error) {
    if (!mounted) return;
    final message = securityKeyErrorMessage(AppLocalizations.of(context)!, error);
    final failure = error is SecurityKeyException ? error.failure : null;
    switch (failure) {
      case SecurityKeyFailure.pinInvalid:
        _pin.clear();
        _stop(_Step.pin, message);
      case SecurityKeyFailure.pinPolicy when _step == _Step.newPin:
        _stop(_Step.newPin, message);
      case SecurityKeyFailure.pinNotSet when widget.enrolling:
        _stop(_Step.newPin);
      case SecurityKeyFailure.uvInvalid when (error as SecurityKeyException).retries != 0:
        _stop(_Step.confirm, message);
      case SecurityKeyFailure.uvInvalid ||
              SecurityKeyFailure.uvBlocked ||
              SecurityKeyFailure.uvNotConfigured
          when _info?.pinSet ?? false:
        _fingerprintOff = true;
        _verification = null;
        _stop(_Step.pin, message);
      case SecurityKeyFailure.cancelled:
        _stop(_Step.connect);
      default:
        _stop(_Step.connect, message);
    }
  }

  void _cancel() => _service.cancel().catchError((Object _) {});

  // ----- Layout -----

  int get _dotCount => widget.enrolling ? 4 : 3;

  int get _dotIndex => switch (_step) {
    _Step.connect => 0,
    _Step.pin || _Step.newPin => 1,
    _Step.confirm => 2,
    _Step.name => 3,
  };

  bool get _nfc => _info?.transport == SecurityKeyTransport.nfc;

  bool get _waitingForUser =>
      _busy &&
      (_status == SecurityKeyStatus.touchNeeded || _status == SecurityKeyStatus.fingerprintNeeded);

  IconData get _glyph {
    if (_step == _Step.name) return Icons.check_rounded;
    if (_status == SecurityKeyStatus.fingerprintNeeded || (_usingFingerprint && !_busy)) {
      return Icons.fingerprint;
    }
    if (_status == SecurityKeyStatus.touchNeeded) return Icons.touch_app_outlined;
    return switch (_step) {
      _Step.pin || _Step.newPin => Icons.pin_outlined,
      _ when _nfc => Icons.contactless_outlined,
      _ => Icons.key_outlined,
    };
  }

  ({String title, String body}) _copy(AppLocalizations i18n) {
    final connectBody = Platform.isIOS
        ? i18n.securityKeyConnectBodyIos
        : i18n.securityKeyConnectBodyAndroid;
    return switch (_step) {
      _Step.connect when _status == SecurityKeyStatus.touchNeeded => (
        title: i18n.securityKeyTouchToSelect,
        body: i18n.securityKeyTouchBody,
      ),
      _Step.connect => (
        title: widget.enrolling ? i18n.securityKeyConnectTitle : i18n.securityKeyUnlockTitle,
        body: connectBody,
      ),
      _Step.pin => (
        title: _known == null
            ? i18n.securityKeyPinTitle
            : i18n.securityKeyPinTitleNamed(_known!.name),
        body: i18n.securityKeyPinBody,
      ),
      _Step.newPin => (
        title: i18n.securityKeysNewPinTitle,
        body: i18n.securityKeysNewPinBodyCount(_info?.minPinLength ?? 4),
      ),
      _Step.confirm => _confirmCopy(i18n),
      _Step.name => (title: i18n.securityKeyAddedTitle, body: i18n.securityKeyNameBody),
    };
  }

  ({String title, String body}) _confirmCopy(AppLocalizations i18n) {
    final second = widget.enrolling && _touches >= 2;
    if (_status == SecurityKeyStatus.fingerprintNeeded || (_usingFingerprint && _touches == 0)) {
      return (
        title: !widget.enrolling
            ? i18n.securityKeyFingerprintToUnlock
            : second
            ? i18n.securityKeyFingerprintOnceMore
            : i18n.securityKeyFingerprintToConfirm,
        body: i18n.securityKeyFingerprintBody,
      );
    }
    if (_status == SecurityKeyStatus.touchNeeded) {
      return (
        title: !widget.enrolling
            ? i18n.securityKeyTouchToUnlock
            : second
            ? i18n.securityKeyTouchOnceMore
            : i18n.securityKeyTouchToConfirm,
        body: i18n.securityKeyTouchBody,
      );
    }
    if (_status == SecurityKeyStatus.waitingForKey) {
      return (
        title: _nfc ? i18n.securityKeyHoldAgain : i18n.securityKeyConnectAgain,
        body: Platform.isIOS ? i18n.securityKeyConnectBodyIos : i18n.securityKeyConnectBodyAndroid,
      );
    }
    return (
      title: _touches > 0 || _usingFingerprint
          ? i18n.securityKeyWorking
          : i18n.securityKeyCheckingPin,
      body: _nfc ? i18n.securityKeyKeepHolding : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final copy = _copy(i18n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: StepDots(count: _dotCount, index: _dotIndex),
        ),
        SizedBox(height: widget.large ? BrandSpacing.xxl : BrandSpacing.xl),
        Center(
          child: _KeyGlyph(
            icon: _glyph,
            pulsing: _waitingForUser,
            done: _step == _Step.name,
            size: widget.large ? 104 : 84,
          ),
        ),
        SizedBox(height: widget.large ? BrandSpacing.xl : BrandSpacing.lg),
        AnimatedSwitcher(
          duration: BrandMotion.transition,
          child: Column(
            key: ValueKey(copy.title),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: widget.large ? BrandText.title : BrandText.sheetTitle,
              ),
              if (copy.body.isNotEmpty) ...[
                const SizedBox(height: BrandSpacing.sm),
                Text(copy.body, textAlign: TextAlign.center, style: BrandText.bodyMuted),
              ],
            ],
          ),
        ),
        const SizedBox(height: BrandSpacing.xl),
        ..._stepBody(i18n),
        if (_error != null) ...[
          const SizedBox(height: BrandSpacing.md),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: BrandText.caption.copyWith(color: BrandColors.error, height: 1.4),
          ),
        ],
        const SizedBox(height: BrandSpacing.lg),
        ..._actions(i18n),
      ],
    );
  }

  List<Widget> _stepBody(AppLocalizations i18n) {
    switch (_step) {
      case _Step.pin:
        final retries = _info?.pinRetries;
        return [
          _pinField(_pin, i18n.securityKeysPinLabel, onSubmitted: _submitPin),
          if (retries != null && retries <= 3 && _error == null) ...[
            const SizedBox(height: BrandSpacing.sm),
            Text(
              i18n.securityKeyPinAttemptsLeft(retries),
              textAlign: TextAlign.center,
              style: BrandText.caption.copyWith(color: BrandColors.warning),
            ),
          ],
        ];
      case _Step.newPin:
        return [
          _pinField(_newPin, i18n.securityKeysNewPinLabel),
          const SizedBox(height: BrandSpacing.md),
          _pinField(_confirmPin, i18n.securityKeysConfirmPinLabel, onSubmitted: _setPin),
          if (_busy) ...[const SizedBox(height: BrandSpacing.md), _statusLine(i18n)],
        ];
      case _Step.name:
        return [BrandTextField(controller: _name, label: i18n.securityKeysNameLabel)];
      case _Step.connect || _Step.confirm:
        if (!_busy) return const [];
        return [_statusLine(i18n)];
    }
  }

  /// One quiet line under the prompt: what the app is waiting on.
  Widget _statusLine(AppLocalizations i18n) {
    final waitingForUser = _waitingForUser;
    final text = switch (_status) {
      null || SecurityKeyStatus.waitingForKey => i18n.securityKeyWaiting,
      SecurityKeyStatus.touchNeeded || SecurityKeyStatus.fingerprintNeeded =>
        widget.enrolling && _step == _Step.confirm
            ? i18n.securityKeyTouchCount(_touches.clamp(1, 2), 2)
            : i18n.securityKeyKeyBlinking,
      _ => i18n.securityKeyTalkingToKey,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!waitingForUser) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.primaryDeep),
          ),
          const SizedBox(width: BrandSpacing.sm),
        ],
        Flexible(
          child: Text(
            text,
            style: BrandText.caption.copyWith(
              color: waitingForUser ? BrandColors.primaryDeep : BrandColors.inkMuted,
              fontWeight: waitingForUser ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _actions(AppLocalizations i18n) {
    if (_busy && _step != _Step.name) {
      return [BrandButton.ghost(label: i18n.cancel, onPressed: _cancel)];
    }
    switch (_step) {
      case _Step.connect:
        return [
          BrandButton(
            label: _started ? i18n.securityKeyTryAgain : i18n.securityKeyConnectButton,
            icon: Icons.key_outlined,
            onPressed: _connect,
          ),
        ];
      case _Step.pin:
        return [
          BrandButton(label: i18n.securityKeysContinue, onPressed: _submitPin),
          if (_canUseFingerprint) ...[
            const SizedBox(height: BrandSpacing.sm),
            BrandButton.ghost(
              label: i18n.securityKeyUseFingerprint,
              onPressed: () => _confirm(const KeyVerification.builtIn()),
            ),
          ],
          const SizedBox(height: BrandSpacing.sm),
          BrandButton.ghost(label: i18n.securityKeyUseAnotherKey, onPressed: _connect),
        ];
      case _Step.newPin:
        return [
          BrandButton(label: i18n.securityKeysSetPinButton, onPressed: _setPin),
          const SizedBox(height: BrandSpacing.sm),
          BrandButton.ghost(label: i18n.securityKeyUseAnotherKey, onPressed: _connect),
        ];
      case _Step.confirm:
        // Only reached idle after a fingerprint was not recognised.
        return [
          BrandButton(
            label: i18n.securityKeyTryAgain,
            icon: Icons.fingerprint,
            onPressed: () => _confirm(const KeyVerification.builtIn()),
          ),
          if (_info?.pinSet ?? false) ...[
            const SizedBox(height: BrandSpacing.sm),
            BrandButton.ghost(label: i18n.securityKeyUsePin, onPressed: () => _stop(_Step.pin)),
          ],
        ];
      case _Step.name:
        return [BrandButton(label: i18n.securityKeySaveName, loading: _busy, onPressed: _saveName)];
    }
  }

  Widget _pinField(TextEditingController controller, String label, {VoidCallback? onSubmitted}) =>
      BrandTextField(
        controller: controller,
        label: label,
        obscureText: _obscure,
        keyboardType: TextInputType.visiblePassword,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        suffix: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: BrandColors.inkMuted,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      );
}

/// The key, drawn large: a tinted disc with the step's glyph, and a ring that
/// pulses outward while the key waits for a touch.
class _KeyGlyph extends StatefulWidget {
  const _KeyGlyph({
    required this.icon,
    required this.pulsing,
    required this.done,
    required this.size,
  });

  final IconData icon;
  final bool pulsing;
  final bool done;
  final double size;

  @override
  State<_KeyGlyph> createState() => _KeyGlyphState();
}

class _KeyGlyphState extends State<_KeyGlyph> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_KeyGlyph old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.pulsing && _pulse.isAnimating) {
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final accent = widget.done ? BrandColors.success : BrandColors.primary;
    final disc = widget.done
        ? BrandColors.successBg
        : widget.pulsing
        ? BrandColors.orangeBg
        : BrandColors.surfaceTinted;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulsing)
                Container(
                  width: size * (1 + 0.5 * t),
                  height: size * (1 + 0.5 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.5 * (1 - t)), width: 2),
                  ),
                ),
              child!,
            ],
          );
        },
        child: AnimatedContainer(
          duration: BrandMotion.transition,
          width: size,
          height: size,
          decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
          child: AnimatedSwitcher(
            duration: BrandMotion.transition,
            child: Icon(
              widget.icon,
              key: ValueKey(widget.icon),
              size: size * 0.44,
              color: widget.done ? BrandColors.success : BrandColors.primaryDeep,
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds one key in a sheet, key first: connect, PIN, touches, then a name.
/// True once added.
Future<bool> showAddSecurityKeySheet(
  BuildContext context, {
  required int number,
  required Future<SecurityKeyRecord> Function(
    KeyVerification verification,
    SecurityKeyAuthenticator key,
    String name,
  )
  enroll,
  required Future<void> Function(SecurityKeyRecord record, String name) rename,
  required Future<List<SecurityKeyRecord>> Function() registeredKeys,
}) async {
  final i18n = AppLocalizations.of(context)!;
  final defaultName = i18n.securityKeysNameDefault(number);
  final added = await showBrandSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isDesktopModal ? 0 : 22,
          isDesktopModal ? 0 : 10,
          isDesktopModal ? 0 : 22,
          16, // showBrandSheet owns the keyboard inset
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(
                i18n.securityKeysAddButton.toUpperCase(),
                textAlign: TextAlign.center,
                style: BrandText.section,
              ),
              const SizedBox(height: BrandSpacing.md),
              SecurityKeyFlow(
                enrolling: true,
                defaultName: defaultName,
                useKey: (verification, key) => enroll(verification, key, defaultName),
                registeredKeys: registeredKeys,
                rename: rename,
                onDone: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return added ?? false;
}
