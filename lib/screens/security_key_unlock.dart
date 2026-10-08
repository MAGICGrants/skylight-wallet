import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/security_key_flow.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Opens a wallet whose password is behind security keys: after a cold start,
/// and after "Fully lock after" has run out. Comes after App Lock when that is
/// on, so the phone's own lock is checked first.
///
/// Key first, like a browser's security-key prompt: connect and touch the
/// key, enter its PIN (or touch a YubiKey Bio's sensor), touch it again.
class SecurityKeyUnlockScreen extends StatelessWidget {
  const SecurityKeyUnlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: BrandSpacing.xl,
                  vertical: BrandSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: SvgPicture.asset('assets/logo_nobg.svg', width: 44, height: 44)),
                    const SizedBox(height: BrandSpacing.xl),
                    SecurityKeyFlow(
                      enrolling: false,
                      large: true,
                      registeredKeys: registeredSecurityKeys,
                      useKey: (verification, key) async {
                        await unlockWithSecurityKey(context, verification, key);
                        return null;
                      },
                      onDone: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/wallet_home',
                        (route) => false,
                      ),
                    ),
                    const SizedBox(height: BrandSpacing.sm),
                    BrandButton.ghost(
                      label: i18n.securityKeyLostKeys,
                      onPressed: () => _showLostKeys(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLostKeys(BuildContext context) async {
    final i18n = AppLocalizations.of(context)!;
    final useSeed = await showConfirmSheet(
      context: context,
      icon: Icons.key_off_outlined,
      iconBg: BrandColors.warningBg,
      iconColor: BrandColors.warning,
      title: i18n.securityKeyLostKeys,
      body: i18n.securityKeyLostKeysBody,
      confirmLabel: i18n.securityKeyUseRecoveryPhrase,
      cancelLabel: i18n.cancel,
    );
    if (!useSeed || !context.mounted) return;
    await showBrandSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const _RecoveryPhraseSheet(),
    );
  }
}

/// Unlocks with the recovery phrase: the FHSE root is derived from the seed,
/// so the phrase rebuilds the wallet password without any key.
class _RecoveryPhraseSheet extends StatefulWidget {
  const _RecoveryPhraseSheet();

  @override
  State<_RecoveryPhraseSheet> createState() => _RecoveryPhraseSheetState();
}

class _RecoveryPhraseSheetState extends State<_RecoveryPhraseSheet> {
  final _phrase = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final i18n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await unlockWithRecoveryPhrase(context, _phrase.text);
      if (!mounted) return;
      _phrase.clear();
      showBrandToast(context, i18n.securityKeyRecoveredToast);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is Exception && e.toString().contains('Invalid mnemonic')
              ? i18n.securityKeyRecoveryWrongPhrase
              : securityKeyErrorMessage(i18n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 10, 22, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(i18n.securityKeyUseRecoveryPhrase, style: BrandText.sheetTitle),
            const SizedBox(height: BrandSpacing.lg),
            BrandTextField(
              controller: _phrase,
              hint: i18n.securityKeyRecoveryPhraseHint,
              maxLines: 4,
              keyboardType: TextInputType.visiblePassword,
            ),
            if (_error != null) ...[
              const SizedBox(height: BrandSpacing.sm),
              Text(_error!, style: BrandText.caption.copyWith(color: BrandColors.error)),
            ],
            const SizedBox(height: BrandSpacing.lg),
            BrandButton(
              label: i18n.securityKeyUnlockButton,
              loading: _busy,
              onPressed: _busy ? null : _unlock,
            ),
          ],
        ),
      ),
    );
  }
}
