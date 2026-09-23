import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:skylight_wallet/widgets/connection_settings_form.dart';
import 'package:skylight_wallet/widgets/ui/ui.dart';

/// Desktop Step 3 of 6 — the LWS/node connection (skylight is LWS-first, so this
/// is part of onboarding). The form runs embedded so its Save moves into the
/// scaffold footer's Continue, on the same row as Back; a [ConnectionFormController]
/// mirrors the form's save gating and triggers the save.
class DesktopConnectionView extends StatefulWidget {
  final String title;
  final String description;
  final String noteServer;
  final String noteChangeable;
  final String saveButtonLabel;
  final VoidCallback onSaved;
  final VoidCallback? onBack;

  const DesktopConnectionView({
    super.key,
    required this.title,
    required this.description,
    required this.noteServer,
    required this.noteChangeable,
    required this.saveButtonLabel,
    required this.onSaved,
    this.onBack,
  });

  @override
  State<DesktopConnectionView> createState() => _DesktopConnectionViewState();
}

class _DesktopConnectionViewState extends State<DesktopConnectionView> {
  final _controller = ConnectionFormController();

  @override
  void dispose() {
    _controller.canSave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.canSave,
      builder: (context, canSave, _) => DesktopOnboardingScaffold(
        logo: SvgPicture.asset('assets/logo_nobg.svg', height: 52),
        title: widget.title,
        description: widget.description,
        step: 3,
        totalSteps: 6,
        continueLabel: widget.saveButtonLabel,
        continueEnabled: canSave,
        onBack: widget.onBack,
        onContinue: _controller.save,
        notes: [
          OnboardingNote(Icons.dns_outlined, widget.noteServer),
          OnboardingNote(Icons.tune, widget.noteChangeable),
        ],
        content: SingleChildScrollView(
          child: ConnectionSettingsForm(
            embedded: true,
            controller: _controller,
            saveButtonLabel: widget.saveButtonLabel,
            onSaved: widget.onSaved,
          ),
        ),
      ),
    );
  }
}
