import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop Step 6 of 6 — set the wallet password (last step; the wallet is
/// created + encrypted here). Reuses the mobile [CreatePasswordLabels]; the
/// strength/match hints and the acknowledgement are desktop-only copy.
class DesktopCreatePasswordView extends StatefulWidget {
  final CreatePasswordLabels labels;
  final String continueText;
  final String noteLaunch;
  final String noteNotCloud;
  final String strongLabel;
  final String matchLabel;
  final String acknowledgeLabel;
  final bool loading;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onBack;

  const DesktopCreatePasswordView({
    super.key,
    required this.labels,
    required this.continueText,
    required this.noteLaunch,
    required this.noteNotCloud,
    required this.strongLabel,
    required this.matchLabel,
    required this.acknowledgeLabel,
    required this.onSubmit,
    this.loading = false,
    this.onBack,
  });

  @override
  State<DesktopCreatePasswordView> createState() => _DesktopCreatePasswordViewState();
}

class _DesktopCreatePasswordViewState extends State<DesktopCreatePasswordView> {
  static const _minLength = 8;

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acknowledged = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _longEnough => _password.text.length >= _minLength;
  bool get _matches => _confirm.text.isNotEmpty && _confirm.text == _password.text;
  bool get _valid => _longEnough && _matches && _acknowledged;

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    return DesktopOnboardingScaffold(
      logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
      title: l.title,
      description: l.description,
      step: 6,
      totalSteps: 6,
      continueLabel: widget.continueText,
      continueEnabled: _valid,
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: () => widget.onSubmit(_password.text),
      notes: [
        OnboardingNote(Icons.lock_outline, widget.noteLaunch),
        OnboardingNote(Icons.cloud_off_outlined, widget.noteNotCloud),
      ],
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          BrandTextField(
            controller: _password,
            label: l.passwordHint,
            obscureText: _obscurePassword,
            suffix: _revealToggle(
              obscured: _obscurePassword,
              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          if (_password.text.isNotEmpty)
            _hint(_longEnough ? widget.strongLabel : l.tooShortError, ok: _longEnough),
          const SizedBox(height: 18),
          BrandTextField(
            controller: _confirm,
            label: l.confirmPasswordHint,
            obscureText: _obscureConfirm,
            suffix: _revealToggle(
              obscured: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          if (_confirm.text.isNotEmpty)
            _hint(_matches ? widget.matchLabel : l.doNotMatchError, ok: _matches),
          const SizedBox(height: 22),
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Text(
                      widget.acknowledgeLabel,
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

  // Same reveal affordance the app's other password fields use.
  Widget _revealToggle({required bool obscured, required VoidCallback onToggle}) => IconButton(
    icon: Icon(
      obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: BrandColors.inkMuted,
    ),
    onPressed: onToggle,
  );

  Widget _hint(String text, {required bool ok}) => Padding(
    padding: const EdgeInsets.only(top: 8, left: 4),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Ubuntu',
        fontSize: 12,
        color: ok ? BrandColors.success : BrandColors.error,
      ),
    ),
  );
}
