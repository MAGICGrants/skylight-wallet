import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart';
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/widgets/fiat_controls.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Fiat API settings popup — how rates are fetched and the display currency.
/// Reuses the onboarding mode cards / currency chips. Resolves to `true` when
/// the user saves a change.
Future<bool?> showFiatApiSettingsSheet(BuildContext context) {
  return showBrandSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _FiatApiSettingsSheet(),
  );
}

class _FiatApiSettingsSheet extends StatefulWidget {
  const _FiatApiSettingsSheet();

  @override
  State<_FiatApiSettingsSheet> createState() => _FiatApiSettingsSheetState();
}

class _FiatApiSettingsSheetState extends State<_FiatApiSettingsSheet> {
  FiatApiMode _mode = FiatApiMode.torOnly;
  String _currency = 'USD';
  bool _loaded = false;

  bool get _globalTorDisabled => TorSettingsService.sharedInstance.torMode == TorMode.disabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await FiatRateModel.loadFiatApiMode();
    final currency =
        await SharedPreferencesService.get<String>(SharedPreferencesKeys.fiatCurrency) ?? 'USD';
    if (!mounted) return;
    setState(() {
      // Tor-only fiat is unreachable with global Tor off; fall back to clearnet.
      _mode = (_globalTorDisabled && mode == FiatApiMode.torOnly) ? FiatApiMode.clearnet : mode;
      _currency = currency;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await FiatRateModel.saveFiatApiMode(_mode);
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, _currency);
    // An explicit choice here supersedes any Tor auto-disable marker.
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
    await FiatRateModel.clearPersistedRates();

    if (!mounted) return;
    final manager = context.read<WalletManager>();
    context.read<FiatRateModel>().startService(walletManager: manager);
    Navigator.of(context).pop(true);
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
                          icon: Icons.attach_money,
                          bg: BrandColors.surfaceAccent,
                          color: BrandColors.cinnamonDeep,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            i18n.settingsFiatApiSettingsLabel,
                            style: BrandText.sheetTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      i18n.fiatApiSettingsSheetSubtitle,
                      style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  child: !_loaded
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(label: i18n.fiatApiSettingsModeLabel),
                            const SizedBox(height: 9),
                            if (!_globalTorDisabled) ...[
                              ModeSelectCard(
                                title: i18n.fiatApiSettingsModeTorOnly,
                                description: i18n.fiatModeTorOnlyDesc,
                                selected: _mode == FiatApiMode.torOnly,
                                onTap: () => setState(() => _mode = FiatApiMode.torOnly),
                              ),
                              const SizedBox(height: 9),
                            ],
                            ModeSelectCard(
                              title: i18n.fiatApiSettingsModeClearnet,
                              description: i18n.fiatModeClearnetDesc,
                              selected: _mode == FiatApiMode.clearnet,
                              onTap: () => setState(() => _mode = FiatApiMode.clearnet),
                            ),
                            const SizedBox(height: 9),
                            ModeSelectCard(
                              title: i18n.fiatApiSettingsModeDisabled,
                              description: i18n.fiatModeDisabledDesc,
                              selected: _mode == FiatApiMode.disabled,
                              onTap: () => setState(() => _mode = FiatApiMode.disabled),
                            ),
                            if (_mode != FiatApiMode.disabled) ...[
                              const SizedBox(height: 16),
                              SectionHeader(label: i18n.fiatApiSettingsDisplayCurrencyLabel),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final code in supportedFiatCurrencies)
                                    FiatCurrencyChip(
                                      code: code,
                                      symbol: currencySymbols[code] ?? '',
                                      selected: _currency == code,
                                      onTap: () => setState(() => _currency = code),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Column(
                  children: [
                    BrandButton(label: i18n.save, onPressed: _save),
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
