import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop Step 2 of 6 — price-display choice (Tor-Only / Clearnet / Disabled)
/// plus the display currency. Reuses the mobile [FiatSetupLabels] and callbacks.
class DesktopFiatSetupView extends StatelessWidget {
  final FiatSetupLabels labels;
  final String noteRatesOnly;
  final String noteTor;
  final List<FiatCurrencyOption> currencies;
  final int modeIndex;
  final String currency;
  final bool offerTorOnly;
  final ValueChanged<int> onModeChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const DesktopFiatSetupView({
    super.key,
    required this.labels,
    required this.noteRatesOnly,
    required this.noteTor,
    required this.currencies,
    required this.modeIndex,
    required this.currency,
    required this.offerTorOnly,
    required this.onModeChanged,
    required this.onCurrencyChanged,
    required this.onContinue,
    this.onBack,
  });

  static const _torOnly = 0, _clearnet = 1, _disabled = 2;

  @override
  Widget build(BuildContext context) {
    return DesktopOnboardingScaffold(
      logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
      title: labels.title,
      description: labels.subtitle,
      step: 2,
      totalSteps: 6,
      continueLabel: labels.continueText,
      onBack: onBack,
      onContinue: onContinue,
      notes: [
        OnboardingNote(Icons.price_change_outlined, noteRatesOnly),
        OnboardingNote(Icons.lock_outline, noteTor),
      ],
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (offerTorOnly) ...[
            OnboardingRadioCard(
              selected: modeIndex == _torOnly,
              icon: Icons.lock_outline,
              title: labels.torOnly,
              description: labels.torOnlyDesc,
              onTap: () => onModeChanged(_torOnly),
            ),
            const SizedBox(height: 10),
          ],
          OnboardingRadioCard(
            selected: modeIndex == _clearnet,
            icon: Icons.public,
            title: labels.clearnet,
            description: labels.clearnetDesc,
            onTap: () => onModeChanged(_clearnet),
          ),
          const SizedBox(height: 10),
          OnboardingRadioCard(
            selected: modeIndex == _disabled,
            icon: Icons.money_off,
            title: labels.disabled,
            description: labels.disabledDesc,
            onTap: () => onModeChanged(_disabled),
          ),
          const SizedBox(height: 26),
          Text(
            labels.currencyLabel,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BrandColors.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in currencies)
                _CurrencyChip(
                  code: c.code,
                  symbol: c.symbol,
                  selected: c.code == currency,
                  onTap: () => onCurrencyChanged(c.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String code;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyChip({
    required this.code,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? BrandColors.surfaceSunken : BrandColors.card,
          border: Border.all(
            color: selected ? BrandColors.primary : BrandColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                fontFamily: 'Ubuntu',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? BrandColors.primary : BrandColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              symbol,
              style: TextStyle(fontFamily: 'Ubuntu', fontSize: 13, color: BrandColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
