import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/widgets/tor_settings_form.dart'
    show TorPortField, TorTestChip, TorTestStatus;
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop Step 1 of 5 — Tor connection choice (Built-in / External / No Tor).
/// Reuses the mobile [TorChoiceLabels] (all i18n) and callbacks; only the dark
/// pane's footnotes are desktop-only copy.
class DesktopTorChoiceView extends StatefulWidget {
  final TorChoiceLabels labels;
  final String notePrivacy;
  final String noteChangeable;
  final Future<bool> Function(String port) onTest;
  final void Function({required int modeIndex, required String port, required bool useOrbot})
  onContinue;
  final VoidCallback? onBack;

  const DesktopTorChoiceView({
    super.key,
    required this.labels,
    required this.notePrivacy,
    required this.noteChangeable,
    required this.onTest,
    required this.onContinue,
    this.onBack,
  });

  @override
  State<DesktopTorChoiceView> createState() => _DesktopTorChoiceViewState();
}

class _DesktopTorChoiceViewState extends State<DesktopTorChoiceView> {
  static const _builtIn = 0, _external = 1, _noTor = 2;

  int? _selected;
  final _portController = TextEditingController(text: '9050');
  final bool _useOrbot = false;
  bool _testing = false;
  bool? _testOk;

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  bool get _canContinue => _selected != null && (_selected != _external || _testOk == true);

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _testOk = null;
    });
    final ok = await widget.onTest(_portController.text.trim());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    return DesktopOnboardingScaffold(
      logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
      title: l.title,
      description: l.subtitle,
      step: 1,
      totalSteps: 6,
      continueLabel: l.continueText,
      continueEnabled: _canContinue,
      onBack: widget.onBack,
      onContinue: _selected == null
          ? null
          : () => widget.onContinue(
              modeIndex: _selected!,
              port: _portController.text.trim(),
              useOrbot: _useOrbot,
            ),
      notes: [
        OnboardingNote(Icons.lock_outline, widget.notePrivacy),
        OnboardingNote(Icons.tune, widget.noteChangeable),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingRadioCard(
            selected: _selected == _builtIn,
            icon: Icons.lock_outline,
            title: l.builtIn,
            description: l.builtInDesc,
            onTap: () => setState(() => _selected = _builtIn),
          ),
          const SizedBox(height: 10),
          OnboardingRadioCard(
            selected: _selected == _external,
            icon: Icons.shield_outlined,
            title: l.external,
            description: l.externalDesc,
            onTap: () => setState(() => _selected = _external),
            trailing: _selected == _external ? _externalForm(l) : null,
          ),
          const SizedBox(height: 10),
          OnboardingRadioCard(
            selected: _selected == _noTor,
            icon: Icons.visibility_outlined,
            title: l.noTor,
            description: l.noTorDesc,
            onTap: () => setState(() => _selected = _noTor),
          ),
        ],
      ),
    );
  }

  Widget _externalForm(TorChoiceLabels l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same labeled port field + compact test chip / inline status as the
        // settings Tor sheet (shared widgets from tor_settings_form).
        TorPortField(
          controller: _portController,
          label: l.socksPortLabel,
          onChanged: () {
            if (_testOk != null) setState(() => _testOk = null);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TorTestStatus(
                testing: _testing,
                tested: _testOk != null,
                ok: _testOk == true,
                connectedLabel: l.connected,
                failedLabel: l.testFailed,
              ),
            ),
            const SizedBox(width: 12),
            TorTestChip(label: l.testButton, onTap: _testing ? null : _runTest),
          ],
        ),
      ],
    );
  }
}
