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
  bool get _valid => _longEnough && _matches;

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
          _passwordField(
            controller: _password,
            label: l.passwordHint,
            obscured: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          if (_password.text.isNotEmpty)
            _hint(_longEnough ? widget.strongLabel : l.tooShortError, ok: _longEnough),
          const SizedBox(height: 18),
          _passwordField(
            controller: _confirm,
            label: l.confirmPasswordHint,
            obscured: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          if (_confirm.text.isNotEmpty)
            _hint(_matches ? widget.matchLabel : l.doNotMatchError, ok: _matches),
        ],
      ),
    );
  }

  /// A labeled inset field — small-caps mono label above a white bordered box —
  /// matching the design and the app's other inputs (not a Material text field).
  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Ubuntu Mono',
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: BrandColors.inkMuted,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: BrandColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscured,
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 16,
                    letterSpacing: obscured ? 3.5 : 0.5,
                    color: BrandColors.ink,
                  ),
                  cursorColor: BrandColors.primary,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Tappable(
                onTap: onToggle,
                child: Icon(
                  obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: BrandColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
