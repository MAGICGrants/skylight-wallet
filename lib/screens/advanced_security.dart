import 'package:flutter/material.dart';
import 'package:wallet_fhse/wallet_fhse.dart' show FhseVault;

import 'package:skylight_wallet/l10n/app_localizations.dart';
import 'package:skylight_wallet/screens/security_key_setup.dart';
import 'package:skylight_wallet/services/shared_preferences_service.dart';
import 'package:skylight_wallet/wallet_core_glue.dart';
import 'package:skylight_wallet/widgets/security_key_flow.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// "Fully lock after" for [minutes], e.g. "30 minutes" or "24 hours".
String fullLockLabel(AppLocalizations i18n, int minutes) =>
    minutes % 60 == 0 ? i18n.securityKeysHours(minutes ~/ 60) : i18n.securityKeysMinutes(minutes);

/// Settings > Advanced security: YubiKeys guarding the wallet password.
///
/// Off by default: onboarding derives the wallet password from the seed (FHSE's
/// root) and keeps it in the keystore as before. Setting keys up takes it out
/// of the keystore; from then on a key and its PIN open the wallet, after App
/// Lock when that is on.
class AdvancedSecurityScreen extends StatefulWidget {
  const AdvancedSecurityScreen({super.key});

  @override
  State<AdvancedSecurityScreen> createState() => _AdvancedSecurityScreenState();
}

class _AdvancedSecurityScreenState extends State<AdvancedSecurityScreen> {
  SecurityKeysState? _state;
  int _fullLockMinutes = fullLockDefaultMinutes;
  bool _turningOff = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await securityKeysState();
    final minutes =
        await SharedPreferencesService.get<int>(SharedPreferencesKeys.fullLockAfterMinutes) ??
        fullLockDefaultMinutes;
    if (!mounted) return;
    setState(() {
      _state = state;
      _fullLockMinutes = minutes;
    });
  }

  Future<void> _setUp({bool again = false}) async {
    await Navigator.pushNamed(
      context,
      '/security_key_setup',
      arguments: SecurityKeySetupArgs(again: again),
    );
    await _load();
  }

  Future<void> _addKey() async {
    // After an unlock with the recovery phrase there is no unlocked FHSE file
    // to add to; the keys are set up again instead.
    if (!FhseVault.hasSession) return _setUp(again: true);
    final count = _state?.keys.length ?? 0;
    await showAddSecurityKeySheet(
      context,
      number: count + 1,
      enroll: (verification, key, name) =>
          addSecurityKey(key: key, verification: verification, name: name),
      rename: renameSecurityKey,
      registeredKeys: registeredSecurityKeys,
    );
    // Reload even when the sheet reports nothing added: the key is added
    // before the name step, so a sheet dismissed there still added it.
    if (mounted) await _load();
  }

  Future<void> _removeKey() async {
    final i18n = AppLocalizations.of(context)!;
    final ok = await showConfirmSheet(
      context: context,
      icon: Icons.key_off_outlined,
      iconBg: BrandColors.surfaceTinted,
      iconColor: BrandColors.primaryDeep,
      title: i18n.securityKeysRemoveTitle,
      body: i18n.securityKeysRemoveExplain,
      confirmLabel: i18n.securityKeysRemoveConfirm,
      cancelLabel: i18n.cancel,
    );
    if (ok && mounted) await _setUp(again: true);
  }

  Future<void> _turnOff() async {
    final i18n = AppLocalizations.of(context)!;
    final ok = await showConfirmSheet(
      context: context,
      icon: Icons.lock_open_outlined,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.securityKeysTurnOff,
      body: i18n.securityKeysTurnOffBody,
      confirmLabel: i18n.securityKeysTurnOffConfirm,
      cancelLabel: i18n.cancel,
    );
    if (!ok || !mounted) return;
    setState(() => _turningOff = true);
    try {
      await turnOffSecurityKeys(context);
      if (mounted) showBrandToast(context, i18n.securityKeysTurnedOff);
    } catch (e) {
      if (mounted) showBrandToast(context, securityKeyErrorMessage(i18n, e) ?? '');
    }
    if (mounted) setState(() => _turningOff = false);
    await _load();
  }

  Future<void> _pickFullLock() async {
    final i18n = AppLocalizations.of(context)!;
    final picked = await showBrandSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(i18n.securityKeysFullLockLabel, style: BrandText.sheetTitle),
              const SizedBox(height: BrandSpacing.xs),
              Text(i18n.securityKeysFullLockDescription, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.lg),
              SettingsGroup(
                tiles: [
                  for (final minutes in fullLockMinuteOptions)
                    InkWell(
                      onTap: () => Navigator.pop(sheetContext, minutes),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(fullLockLabel(i18n, minutes), style: BrandText.listTitle),
                            ),
                            RadioDot(selected: minutes == _fullLockMinutes),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await SharedPreferencesService.set<int>(SharedPreferencesKeys.fullLockAfterMinutes, picked);
    if (mounted) setState(() => _fullLockMinutes = picked);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final state = _state;

    final List<Widget> content;
    if (state == null) {
      content = [const Center(child: CircularProgressIndicator())];
    } else if (!state.available && !state.engaged) {
      content = [
        BrandCard(
          padding: const EdgeInsets.all(BrandSpacing.lg),
          child: Text(i18n.securityKeysUnavailable, style: BrandText.body),
        ),
      ];
    } else if (!state.engaged) {
      content = [
        BrandCard(
          padding: const EdgeInsets.all(BrandSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n.securityKeysIntroTitle, style: BrandText.listTitle),
              const SizedBox(height: BrandSpacing.sm),
              Text(i18n.securityKeysIntroBody, style: BrandText.body),
              const SizedBox(height: BrandSpacing.md),
              Text(
                i18n.securityKeysRequirements,
                style: BrandText.caption.copyWith(color: BrandColors.inkMuted),
              ),
              const SizedBox(height: BrandSpacing.sm),
              Text(
                i18n.securityKeysSuggestTwo,
                style: BrandText.caption.copyWith(color: BrandColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: BrandSpacing.xl),
        BrandButton(
          label: i18n.securityKeysSetUpButton,
          icon: Icons.key_outlined,
          onPressed: _setUp,
        ),
      ];
    } else {
      content = [
        if (state.keys.length == 1) ...[
          BrandCard(
            color: BrandColors.warningBg,
            borderColor: BrandColors.warningBg,
            padding: const EdgeInsets.all(BrandSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 19, color: BrandColors.warning),
                const SizedBox(width: BrandSpacing.md),
                Expanded(child: Text(i18n.securityKeysOneKeyWarning, style: BrandText.body)),
              ],
            ),
          ),
          const SizedBox(height: BrandSpacing.xl),
        ],
        SettingsGroup(
          label: i18n.securityKeysYourKeys,
          tiles: [for (final key in state.keys) SecurityKeyTile(record: key)],
        ),
        const SizedBox(height: BrandSpacing.md),
        BrandButton.outline(label: i18n.securityKeysAddButton, icon: Icons.add, onPressed: _addKey),
        const SizedBox(height: 18),
        SettingsGroup(
          label: i18n.securityKeysLockSection,
          tiles: [
            SettingsNavTile(
              title: i18n.securityKeysFullLockLabel,
              value: fullLockLabel(i18n, _fullLockMinutes),
              onTap: _pickFullLock,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, BrandSpacing.sm, 4, 0),
          child: Text(
            i18n.securityKeysFullLockDescription,
            style: BrandText.caption.copyWith(color: BrandColors.inkMuted),
          ),
        ),
        const SizedBox(height: 18),
        SettingsGroup(
          label: i18n.securityKeysManageSection,
          tiles: [
            SettingsLinkTile(
              title: i18n.securityKeysRemoveTitle,
              subtitle: i18n.securityKeysRemoveSubtitle,
              linkLabel: i18n.securityKeysRemoveLink,
              onTap: _removeKey,
            ),
            SettingsLinkTile(
              title: i18n.securityKeysTurnOff,
              titleColor: BrandColors.error,
              onTap: _turningOff ? () {} : _turnOff,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, BrandSpacing.md, 4, 0),
          child: Text(
            i18n.securityKeysBackgroundNote,
            style: BrandText.caption.copyWith(color: BrandColors.inkMuted),
          ),
        ),
      ];
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    onBack: () => Navigator.pop(context),
                    center: Text(
                      i18n.advancedSecurityTitle,
                      style: BrandText.appBar.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
