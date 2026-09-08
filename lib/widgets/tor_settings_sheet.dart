import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/widgets/tor_mode_selector.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Tor settings popup — the same three modes as the onboarding step, as radio
/// cards. Resolves to `true` when a new configuration is saved (the caller then
/// reconnects), or null on dismiss/cancel.
Future<bool?> showTorSettingsSheet(BuildContext context) {
  return showBrandSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TorSettingsSheet(),
  );
}

class _TorSettingsSheet extends StatefulWidget {
  const _TorSettingsSheet();

  @override
  State<_TorSettingsSheet> createState() => _TorSettingsSheetState();
}

class _TorSettingsSheetState extends State<_TorSettingsSheet> {
  late TorSelection _sel = TorSelection(
    mode: TorSettingsService.sharedInstance.torMode,
    port: TorSettingsService.sharedInstance.socksPort,
    useOrbot: TorSettingsService.sharedInstance.useOrbot,
    // Built-in / No Tor commit immediately; External must pass a test first.
    canCommit: TorSettingsService.sharedInstance.torMode != TorMode.external,
  );

  Future<void> _save() async {
    if (!_sel.canCommit) return;
    final mode = _sel.mode!;
    final previousMode = TorSettingsService.sharedInstance.torMode;
    final disablingTor = mode == TorMode.disabled && previousMode != TorMode.disabled;
    final enablingTor = mode != TorMode.disabled && previousMode == TorMode.disabled;

    if (disablingTor) {
      final affected = context.read<WalletManager>().allWallets.where((w) => w.usingTor).toList();
      if (affected.isNotEmpty) {
        final confirmed = await _confirmDisableTor();
        if (confirmed != true) return;
        for (final wallet in affected) {
          wallet.onGlobalTorDisabled();
        }
      }
    }

    // The fiat API can't reach Kraken over a Tor that's now off, so a Tor-only
    // fiat setting is turned off too — remembering it was us, not the user, so
    // re-enabling Tor can restore it.
    if (disablingTor && await FiatRateModel.loadFiatApiMode() == FiatApiMode.torOnly) {
      await FiatRateModel.saveFiatApiMode(FiatApiMode.disabled);
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.fiatAutoDisabledByTor, true);
    }
    // Turning Tor back on restores the fiat API to Tor mode, but only if we were
    // the ones who disabled it.
    if (enablingTor &&
        (await SharedPreferencesService.get<bool>(SharedPreferencesKeys.fiatAutoDisabledByTor) ??
            false)) {
      await FiatRateModel.saveFiatApiMode(FiatApiMode.torOnly);
      await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
    }

    await TorSettingsService.sharedInstance.save(
      torMode: mode,
      socksPort: _sel.port,
      useOrbot: _sel.useOrbot,
    );
    if (!mounted) return;
    final manager = context.read<WalletManager>();
    manager.syncInBackground();
    context.read<FiatRateModel>().startService(walletManager: manager);
    Navigator.of(context).pop(true);
  }

  Future<bool?> _confirmDisableTor() {
    final i18n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: BrandColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n.torDisabledWalletsWarningTitle, style: BrandText.sheetTitle),
              const SizedBox(height: 12),
              Text(i18n.torDisabledWalletsWarningBody, style: BrandText.bodyMuted),
              const SizedBox(height: 22),
              BrandButton(label: i18n.cancel, onPressed: () => Navigator.pop(dialogContext, false)),
              const SizedBox(height: 4),
              BrandButton.ghost(
                label: i18n.torDisabledWalletsWarningConfirm,
                color: BrandColors.error,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SheetIcon(
                          icon: Icons.public,
                          bg: BrandColors.purpleBg,
                          color: BrandColors.purple,
                        ),
                        const SizedBox(width: 11),
                        Expanded(child: Text(i18n.torSettingsTitle, style: BrandText.sheetTitle)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      i18n.torSettingsSheetSubtitle,
                      style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: TorModeSelector(
                    initialMode: TorSettingsService.sharedInstance.torMode,
                    initialPort: TorSettingsService.sharedInstance.socksPort,
                    initialUseOrbot: TorSettingsService.sharedInstance.useOrbot,
                    onChanged: (s) => setState(() => _sel = s),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Column(
                  children: [
                    BrandButton(label: i18n.save, onPressed: _sel.canCommit ? _save : null),
                    const SizedBox(height: 2),
                    BrandButton.ghost(
                      label: i18n.cancel,
                      color: BrandColors.inkMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
