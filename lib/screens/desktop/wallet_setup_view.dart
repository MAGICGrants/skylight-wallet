import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop Step 4 of 6 — create-new vs restore. Selection then Continue (rather
/// than the mobile immediate-navigate). Card title/description reuse the mobile
/// [CreateWalletLabels]; the feature bullets are desktop-only copy.
class DesktopWalletSetupView extends StatefulWidget {
  final CreateWalletLabels labels;
  final String continueText;
  final String noteGenerated;
  final String noteRestore;
  final List<String> createBullets;
  final List<String> restoreBullets;
  final VoidCallback onCreateNew;
  final VoidCallback onRestore;
  final VoidCallback? onBack;

  const DesktopWalletSetupView({
    super.key,
    required this.labels,
    required this.continueText,
    required this.noteGenerated,
    required this.noteRestore,
    required this.createBullets,
    required this.restoreBullets,
    required this.onCreateNew,
    required this.onRestore,
    this.onBack,
  });

  @override
  State<DesktopWalletSetupView> createState() => _DesktopWalletSetupViewState();
}

class _DesktopWalletSetupViewState extends State<DesktopWalletSetupView> {
  static const _new = 0, _restore = 1;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    return DesktopOnboardingScaffold(
      logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
      title: l.title,
      description: l.subtitle,
      step: 4,
      totalSteps: 6,
      continueLabel: widget.continueText,
      continueEnabled: _selected != null,
      onBack: widget.onBack,
      onContinue: _selected == null
          ? null
          : (_selected == _new ? widget.onCreateNew : widget.onRestore),
      notes: [
        OnboardingNote(Icons.key_outlined, widget.noteGenerated),
        OnboardingNote(Icons.history, widget.noteRestore),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingRadioCard(
            selected: _selected == _new,
            icon: Icons.auto_awesome_outlined,
            title: l.createNew,
            description: l.createNewDesc,
            onTap: () => setState(() => _selected = _new),
            trailing: _Bullets(widget.createBullets),
          ),
          const SizedBox(height: 10),
          OnboardingRadioCard(
            selected: _selected == _restore,
            icon: Icons.download_outlined,
            title: l.restore,
            description: l.restoreDesc,
            onTap: () => setState(() => _selected = _restore),
            trailing: _Bullets(widget.restoreBullets),
          ),
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets(this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check, size: 14, color: BrandColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      fontSize: 12.5,
                      height: 1.5,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
