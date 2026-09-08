import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:spice_wallet/widgets/ui/ui.dart';

/// Seed words show in 3 columns, dropping to 2 on screens narrower than a
/// Pixel 8a (~411dp) so the mono words aren't cramped. Shared by the generate,
/// reveal, and restore screens.
int seedGridColumns(BuildContext context) => MediaQuery.of(context).size.width < 410 ? 2 : 3;

/// Numbered seed words in a 3-column grid, blurred behind a "Tap to reveal"
/// overlay until the user explicitly reveals them. Shared by the onboarding
/// generate-seed step and the settings reveal-seed screen.
class SeedGrid extends StatelessWidget {
  final List<String> words;
  final bool revealed;
  final String revealLabel;
  final String screenshotNote;
  final VoidCallback onReveal;

  const SeedGrid({
    super.key,
    required this.words,
    required this.revealed,
    required this.revealLabel,
    required this.screenshotNote,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final cols = seedGridColumns(context);
    // Manual rows (not a GridView) so a lone last word — e.g. word 15 in a
    // 2-column layout — spans the full width instead of one column.
    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r * cols < words.length; r++) ...[
          if (r > 0) const SizedBox(height: 9),
          Row(
            children: [
              for (var c = 0; c < cols && r * cols + c < words.length; c++) ...[
                if (c > 0) const SizedBox(width: 9),
                Expanded(
                  child: _WordCell(index: r * cols + c + 1, word: words[r * cols + c]),
                ),
              ],
            ],
          ),
        ],
      ],
    );

    if (revealed) return grid;

    // Covered: blurred cells behind a dark reveal affordance + a safety note.
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: grid),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onReveal,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BrandColors.inverseSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility_off_outlined,
                      color: BrandColors.onCinnamon,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: BrandSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      color: BrandColors.inverseSurface,
                      borderRadius: BrandRadii.rPill,
                    ),
                    child: Text(
                      revealLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.onCinnamon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BrandSpacing.md),
            Text(
              screenshotNote,
              textAlign: TextAlign.center,
              style: BrandText.caption.copyWith(color: BrandColors.inkFaint),
            ),
          ],
        ),
      ],
    );
  }
}

/// One bordered seed-word cell: zero-padded index + the word in mono.
class _WordCell extends StatelessWidget {
  final int index;
  final String word;

  const _WordCell({required this.index, required this.word});

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      radius: 11,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        // Top-align so the number stays on the first line if a long word wraps.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index.toString().padLeft(2, '0'),
            style: BrandText.mono.copyWith(fontSize: 11, color: BrandColors.inkFaint),
          ),
          const SizedBox(width: BrandSpacing.sm),
          Expanded(
            // No ellipsis — a seed word must be read in full, so wrap instead.
            child: Text(
              word,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BrandColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wallet birthday (restore-point month) with its rationale.
class SeedBirthdayCard extends StatelessWidget {
  final String label;
  final String reason;
  final String value;

  const SeedBirthdayCard({
    super.key,
    required this.label,
    required this.reason,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        borderRadius: BrandRadii.rField,
        border: Border.all(color: BrandColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BrandText.listTitle),
                const SizedBox(height: 2),
                Text(reason, style: BrandText.caption),
              ],
            ),
          ),
          const SizedBox(width: BrandSpacing.md),
          Text(value, style: BrandText.amount),
        ],
      ),
    );
  }
}
