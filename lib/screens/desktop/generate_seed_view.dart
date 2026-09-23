import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop Step 5 of 6 (new wallet) — shows the generated seed words + wallet
/// birthday, gated by a confirmation checkbox. Continue hands the seed to the
/// password step, which encrypts + creates the wallet.
class DesktopGenerateSeedView extends StatefulWidget {
  final String title;
  final String description;
  final List<String> seedWords;
  final String birthdayLabel;
  final String birthdayReason;
  final String? birthdayValue;
  final String confirmLabel;
  final String screenshotNote;
  final String passwordNote;
  final String continueText;
  final bool loading;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const DesktopGenerateSeedView({
    super.key,
    required this.title,
    required this.description,
    required this.seedWords,
    required this.birthdayLabel,
    required this.birthdayReason,
    required this.confirmLabel,
    required this.screenshotNote,
    required this.passwordNote,
    required this.continueText,
    required this.onContinue,
    this.birthdayValue,
    this.loading = false,
    this.onBack,
  });

  @override
  State<DesktopGenerateSeedView> createState() => _DesktopGenerateSeedViewState();
}

class _DesktopGenerateSeedViewState extends State<DesktopGenerateSeedView> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return DesktopOnboardingScaffold(
      logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
      title: widget.title,
      description: widget.description,
      step: 5,
      totalSteps: 6,
      continueLabel: widget.continueText,
      continueEnabled: _confirmed,
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: widget.onContinue,
      notes: [
        OnboardingNote(Icons.edit_outlined, widget.screenshotNote),
        OnboardingNote(Icons.lock_outline, widget.passwordNote),
      ],
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 4.4,
            children: [
              for (var i = 0; i < widget.seedWords.length; i++)
                _SeedCell(index: i + 1, word: widget.seedWords[i]),
            ],
          ),
          if (widget.birthdayValue != null) ...[
            const SizedBox(height: 16),
            _BirthdayCard(
              label: widget.birthdayLabel,
              reason: widget.birthdayReason,
              value: widget.birthdayValue!,
            ),
          ],
          const SizedBox(height: 18),
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => setState(() => _confirmed = !_confirmed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _confirmed,
                  onChanged: (v) => setState(() => _confirmed = v ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Text(
                      widget.confirmLabel,
                      style: TextStyle(
                        fontFamily: 'Ubuntu',
                        fontSize: 13,
                        height: 1.5,
                        color: BrandColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeedCell extends StatelessWidget {
  final int index;
  final String word;
  const _SeedCell({required this.index, required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            index.toString().padLeft(2, '0'),
            style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkFaint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              word,
              style: TextStyle(
                fontFamily: 'Ubuntu',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: BrandColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayCard extends StatelessWidget {
  final String label;
  final String reason;
  final String value;
  const _BirthdayCard({required this.label, required this.reason, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reason,
                  style: TextStyle(fontFamily: 'Ubuntu', fontSize: 12.5, color: BrandColors.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: BrandColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
